module jake

import benchmark
import cli { Command }
import mvn
import net.http
import net.html
import java
import json
import os
import readline
import utils { check_tool, if_bench, log, log_error, log_fatal, log_info }

const (
	dependencies_tag = 'dependencies'
	dependency_tag   = 'dependency'
	group_id_tag     = 'groupid'
	artifact_id_tag  = 'artifactid'
	version_tag      = 'version'
	scope_tag        = 'scope'
	properties_tag   = 'properties'
)

// jake init exec function
pub fn init(cmd Command) ! {
	mut r := readline.Readline{}
	r.enable_raw_mode_nosig()
	defer {
		r.disable_raw_mode()
	}

	// fixme 23/10/27: Handle errors
	mut name := ''
	mut version := '1.0.0'
	for {
		name = r.read_line('Project name: ')!
		if name == '' {
			println("Project name isn't optional")
		} else {
			break
		}
	}

	mut tmp := r.read_line('Version [1.0.0]: ')!
	if tmp != '' {
		version = tmp
	}

	jk := utils.JakeProject{
		name: name
		version: version
	}

	res := json.encode_pretty(jk)
	os.write_file('${os.getwd()}/jakefile.json', res) or { println(err) }
	println('Success! Created jake file at ${os.getwd()}.')
	load_project() // Call load project to setup the project structure
}

// jake build exec function
pub fn build(cmd Command) ! {
	build_project(false, '')
}

// jake build run <args>
pub fn buildrun(cmd Command) ! {
	build_project(true, cmd.args.join(' '))
}

// jake run <args>
pub fn run(cmd Command) ! {
	proj := load_project()
	run_project(proj, cmd.args.join(' '))
}

// jake test
pub fn test(cmd Command) ! {
	build_project(false, '')
	build_and_run_project_tests(false, '')
}

// jake test single
pub fn testsingle(cmd Command) ! {
	build_project(false, '')
	build_and_run_project_tests(true, cmd.args[0])
}

// jake sym
pub fn sym(cmd Command) ! {
	jake_exec := os.real_path('./jake')
	os.rm('/usr/local/bin/jake') or {} // silent fail
	os.symlink(jake_exec, '/usr/local/bin/jake') or {
		eprintln("Couldn't create soft link to `/usr/local/bin`. Try with sudo.")
		exit(1)
	}
}

fn load_project() utils.JakeProject {
	mut b := benchmark.start()

	// 1. Decode jakefile.json present where the jake bin was called
	mut jake_proj := json.decode(utils.JakeProject, os.read_file('./jakefile.json') or {
		log_error("Couldn't read jakefile in root folder.")
		exit(1)
	}) or {
		log_error('> Failed to load project! ERROR: ${err}')
		exit(1)
	}

	if_bench(mut b, 'LoadProject: decode jakefile')

	// 2.  Check for existance of certain tools like java, jar, javac and wget
	if !os.exists('.cache/hastools') {
		check_tool('java')
		check_tool('jar')
		check_tool('javac')
		check_tool('wget')

		// Try create the cache folder since this normally runs only one time
		utils.make_dir('.cache')
		os.create('.cache/hastools') or {
			eprintln('ERR: Couldn\'t create file at ".cache/hastools". ${err}')
			exit(1)
		}
	}

	if_bench(mut b, 'LoadProject: check tools')

	// 3. Try to create the folder structure
	utils.make_dir('build')
	utils.make_dir('build/main')
	utils.make_dir('.cache')
	utils.make_dir('.cache/deps')
	utils.make_dir('libs')
	utils.make_dir('src')
	utils.make_dir('src/main')
	if jake_proj.include_testing {
		utils.make_dir('build/tests')
		utils.make_dir('src/tests')
	}

	// 4. Populate the struct
	jake_proj.pwd = os.getwd()
	jake_proj.src_dir_path = './src/main'
	jake_proj.tests_dir_path = './src/tests'
	jake_proj.build_dir_path = './build/main'
	jake_proj.build_tests_dir_path = './build/tests'
	jake_proj.libs_dir_path = './libs'
	jake_proj.jar_name = '${jake_proj.name}-${jake_proj.version}.jar'
	jake_proj.sources = os.walk_ext(jake_proj.src_dir_path, 'java')
	jake_proj.libs = os.walk_ext(jake_proj.libs_dir_path, 'jar')

	if_bench(mut b, 'LoadProject: setup project')

	// 5. Check if the project has tests enabled, and then setup for testing
	if jake_proj.include_testing {
		jake_proj.tests = os.walk_ext(jake_proj.tests_dir_path, 'java')
		setup_testing(jake_proj)
		if_bench(mut b, 'LoadProject: setup testing')
	}

	// 6. Resolve dependency
	if jake_proj.deps.len > 0 {
		if jake_proj.repos.len == 0 {
			log_error('Resolving dependencies without any repositories defined.')
		}

		try_resolve_dep(mut jake_proj)
		if_bench(mut b, 'LoadProject: resolve dependencies.')
	}

	return jake_proj
}

fn build_project(run bool, args string) {
	// 1. Load project
	mut jake_proj := load_project()

	// 2. Do java stuff
	java.compile_srcs(mut jake_proj)
	java.create_jar(jake_proj)

	// 3. Move the built jar to the project root directory
	jar_path := '${jake_proj.build_dir_path}/${jake_proj.jar_name}'
	if os.exists(jar_path) {
		os.mv(jar_path, '.') or {
			log_error("Couldn't move final jar from build folder to the root of the project. ERR: ${err}")
			exit(1)
		}
	}

	// 4. Run the project if necessary
	if run {
		run_project(jake_proj, args)
	}
}

fn build_and_run_project_tests(run_single bool, single_classpath string) {
	// 1. Load project
	mut jake_proj := load_project()

	// 2. Check if project includes testing
	if !jake_proj.include_testing {
		log_error('> Jake option `include_testing` is false. Change it to true to include testing framework.')
		exit(1)
	}

	// 3. Compile the tests
	java.compile_tests(jake_proj)

	// 4. Run them
	run_tests(jake_proj, run_single, single_classpath)
}

fn run_project(jake_proj utils.JakeProject, args string) {
	mut b := benchmark.start()

	mut cmd := ''

	// 1. Construct classpath
	if jake_proj.libs.len > 0 {
		cmd += '-cp .'
		for lib in jake_proj.libs {
			cmd += ':${lib}'
		}
		cmd += ':${jake_proj.jar_name} ${jake_proj.entry_point} ${args}'
	} else {
		cmd += '-jar ${jake_proj.jar_name} ${args}'
	}

	log('> java ${cmd}')

	if_bench(mut b, 'Gen run command')

	// 2. Exec command and print output.
	os.execvp('java', cmd.split(' ')) or {
		eprintln('Err: ${err}')
		exit(1)
	}
}

fn run_tests(jk utils.JakeProject, run_single bool, single_classpath string) {
	mut b := benchmark.start()

	// 1. Check if project has testing enabled
	if !jk.include_testing {
		log_error('> Jake option `include_testing` is false. Change it to true to include testing framework.')
		exit(1)
	}

	mut cmd := '-cp .:${jk.build_tests_dir_path}'

	// 2 . Contruct classpath
	for lib in jk.libs {
		cmd += ':${lib}'
	}

	cmd += ':.cache/junit-${utils.junit_version}.jar:.cache/hamcrest-core-${utils.hamcrest_version}.jar'

	cmd += ':${jk.jar_name} org.junit.runner.JUnitCore'

	mut tests := ''
	// 3 . Collect tests

	if run_single {
		tests += ' ${single_classpath}'
	} else {
		for test in jk.tests {
			classpath := test.replace('${jk.tests_dir_path}/', '').replace('/', '.').replace('.java',
				'')
			tests += ' ${classpath}'
		}
	}

	cmd += tests

	log('> java ${cmd}')

	if_bench(mut b, 'Gen run tests command')

	// 4 . Exec command
	os.execvp('java', cmd.split(' ')) or {
		eprintln('Err: ${err}')
		exit(1)
	}
}

fn try_resolve_dep(mut jk utils.JakeProject) {
	mut b := benchmark.new_benchmark()

	for dep in jk.deps {
		mvn_obj := from_dep_format(dep)
		jar_name := mvn_obj.to_name(.jar)

		// 1. Early cache check.
		if os.exists('${jk.pwd}/.cache/deps/${jar_name}') {
			log_info('> Found ${jar_name}')
			jk.libs << '${jk.pwd}/.cache/deps/${jar_name}'
			continue
		} else {
			log_info('> Resolving ${jar_name}')
		}

		// 2. Check availability in repos.
		mut not_found := []string{}
		mut resolved := false

		for repo in jk.repos {
			b.step()
			mut res := process_mvn_obj(mvn_obj, repo, mut jk)
			if !res {
				not_found << 'Dependency ${dep} not resolve in ${repo} with full url: ${mvn_obj.as_url(.jar)}'
			} else {
				resolved = true
			}
			if_bench(mut b, 'TryResolveDep: process maven object.')
		}

		// 3. Print errors if couldn't be found in any repo
		if !resolved {
			log_fatal(not_found.join_lines())
		} else {
			jk.libs << '${jk.pwd}/.cache/deps/${jar_name}'
		}
	}
}

// fixme 23/10/31: Implement this with new MavenObj api and add test scope
fn setup_testing(jk utils.JakeProject) {
	// fixme 23/09/19: This should be replaced with global repositories later like maven or gradle.
	hamcrest_url := 'https://repo1.maven.org/maven2/org/hamcrest/hamcrest-core/${utils.hamcrest_version}/hamcrest-core-${utils.hamcrest_version}.jar'
	junit_url := 'https://repo1.maven.org/maven2/junit/junit/${utils.junit_version}/junit-${utils.junit_version}.jar'

	// 1. Check for existance of junit and hamcrest and downloaded them if needed.
	if !os.exists('${jk.pwd}/.cache/junit-${utils.junit_version}.jar') {
		log('> JUnit not found. Downloading junit-${utils.junit_version}...')
		out, rc := utils.execute_in_dir('wget -q ${junit_url}', '${jk.pwd}/.cache/')
		os.wait()
		if rc > 0 {
			log_error(out)
			exit(rc)
		}
		log('> Ok.')
	}

	if !os.exists('${jk.pwd}/.cache/hamcrest-core-${utils.hamcrest_version}.jar') {
		log('> Hamcrest not found. Downloading junit-${utils.junit_version}:')
		out, rc := utils.execute_in_dir('wget -q ${hamcrest_url}', '${jk.pwd}/.cache/')
		os.wait()
		if rc > 0 {
			log_error(out)
			exit(rc)
		}
		log('> Ok.')
	}
}

fn from_dep_format(dep string) mvn.MavenObj {
	// Format:
	// 		junit:junit:4.13.2
	//		|     |     |
	//		|     |     -> version
	//		|     -> artifact_id
	//		-> group
	format := dep.split(':')
	if format.len != 3 {
		log_error('Error in dependency format: [group]:[artifact_id]:[version]. ${dep}')
	}
	return mvn.MavenObj{
		group: format[0]
		artifact_id: format[1]
		version: format[2]
	}
}

fn process_mvn_obj(mvn_obj mvn.MavenObj, repo string, mut jk utils.JakeProject) bool {
	// 1. Fetch the maven pom and parse the xml
	//		- Required to resolve dependencies
	//		- Read properties for ${prop}
	pom_url := repo + mvn_obj.as_url(.pom)
	mut res := http.fetch(url: pom_url) or { log_fatal('Err: ${err}') }

	match res.status() {
		.ok {
			// Note: Download local copy of pom or get its contests?
			doc := html.parse(http.get_text(pom_url))
			deps := doc.get_tags(name: jake.dependencies_tag)
			if deps.len > 0 {
				for dep in deps[0].get_tags(jake.dependency_tag) {
					dep_scope_tag := dep.get_tags(jake.scope_tag)
					if dep_scope_tag.len != 0 {
						if dep_scope_tag[0].text() == 'test' {
							continue
						}
					}
					// We dont check if get_tags is empty because all the fields arent optional on maven pom spec
					// vfmt off
					dep_group_id_tag := try_parse_property(dep.get_tags(jake.group_id_tag)[0].text(), doc)
					dep_artifact_id_tag := try_parse_property(dep.get_tags(jake.artifact_id_tag)[0].text(), doc)

					// fixme 23/10/31: parse all version specifications
					mut dep_version_tag := try_parse_property(dep.get_tags(jake.version_tag)[0].text(), doc)
					// vfmt on

					if dep_version_tag.starts_with('[') {
						// Use first version available. Not the right way to do it btw.
						dep_version_tag = dep_version_tag.substr(1, dep_version_tag.index_after(',',
							1))
					}

					// 1.1 Try resolve the dependency.
					dependency_mvn_obj := mvn.MavenObj{
						group: dep_group_id_tag
						artifact_id: dep_artifact_id_tag
						version: dep_version_tag
					}

					if !process_mvn_obj(dependency_mvn_obj, repo, mut jk) {
						log_fatal('Couldnt resolve dependency: ${dependency_mvn_obj.to_name(.jar)} for ${mvn_obj.to_name(.jar)}')
					}
				}
			}
		}
		else {
			return false
		}
	}
	// 2. Try download the main dependency.
	return download_mvn_obj(mvn_obj, repo, mut jk, false)
}

fn download_mvn_obj(mvn_obj mvn.MavenObj, repo string, mut jk utils.JakeProject, check_cache bool) bool {
	jar_name := mvn_obj.to_name(.jar)
	if check_cache {
		// 1. Check cache again when downloading dependency dependencies
		if os.exists('${jk.pwd}/.cache/deps/${jar_name}') {
			log_info('> Found ${jar_name}')
			jk.libs << '${jk.pwd}/.cache/deps/${jar_name}'
			return true
		} else {
			log_info('> Resolving ${jar_name}')
		}
	}

	// 2. Fetch the given maven object and download it.
	jar_url := repo + mvn_obj.as_url(.jar)
	mut res := http.fetch(url: jar_url) or { log_fatal('Err: ${err}') }

	match res.status() {
		.ok {
			http.download_file(jar_url, '${jk.pwd}/.cache/deps/${jar_name}') or {
				log_fatal('Err: ${err}')
			}
		}
		else {
			return false
		}
	}
	return true
}

// check if the value is a property, if so lookup pom and try to find the property
fn try_parse_property(value string, doc html.DocumentObjectModel) string {
	if value.starts_with('$') {
		props := doc.get_tags(name: jake.properties_tag)
		if props.len > 0 {
			prop_tag := props[0].get_tags(value[2..value.len - 1].to_lower())
			if prop_tag.len > 0 {
				return prop_tag[0].text()
			}
			log_fatal('Pom contains properties tag, but ${value[2..value.len - 1]} was not found')
		} else {
			log_fatal('Pom doesnt contain properties tag!')
		}
	}
	return value
}
