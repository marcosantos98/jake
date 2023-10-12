module jake

import benchmark
import cli { Command }
import java
import json
import os
import strings
import utils { check_tool, if_bench, log, log_error }

// jake build exec function
pub fn build(cmd Command) ! {
	build_project(false, '')
}

// jake build run <args>
pub fn buildrun(cmd Command) ! {
	build_project(true, cmdargs_to_str(cmd))
}

// jake run <args>
pub fn run(cmd Command) ! {
	proj := load_project()
	run_project(proj, cmdargs_to_str(cmd))
}

// jake test
pub fn test(cmd Command) ! {
	build_and_run_project_tests()
}

fn cmdargs_to_str(cmd Command) string {
	mut args_builder := strings.new_builder(1024)
	for arg in cmd.args {
		args_builder.write_string('${arg} ')
	}
	if cmd.args.len > 0 {
		args_builder.go_back(1)
	}

	args := args_builder.str()
	unsafe { args_builder.free() }
	return args
}

fn load_project() utils.JakeProject {
	mut b := benchmark.start()

	// 1. Check for existance of certain tools like java, jar, javac and wget

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

	// 2. Decode jakefile.json present where the jake bin was called
	mut jake_proj := json.decode(utils.JakeProject, os.read_file('./jakefile.json') or {
		log_error("Couldn't read jakefile in root folder.")
		exit(1)
	}) or {
		log_error('> Failed to load project! ERROR: ${err}')
		exit(1)
	}

	if_bench(mut b, "LoadProject: decode jakefile")

	// 3. Try to create the folder structure
	utils.make_dir('build')
	utils.make_dir('build/main')
	utils.make_dir('.cache')
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

	return jake_proj
}

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

fn build_project(run bool, args string) {
	// 1. Load project
	mut jake_proj := load_project()

	// 2. Do java stuff
	java.compile_srcs(jake_proj)
	java.create_jar(jake_proj)

	// 3. Move the built jar to the project root directory
	os.mv('${jake_proj.build_dir_path}/${jake_proj.jar_name}', '.') or {
		log_error("Couldn't move final jar from build folder to the root of the project. ERR: ${err}")
		exit(1)
	}

	// 4. Run the project if necessary
	if run {
		run_project(jake_proj, args)
	}
}

fn build_and_run_project_tests() {
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
	run_tests(jake_proj)
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

fn run_tests(jk utils.JakeProject) {
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
	for test in jk.tests {
		classpath := test.replace('${jk.tests_dir_path}/', '').replace('/', '.').replace('.java',
			'')
		tests += ' ${classpath}'
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
