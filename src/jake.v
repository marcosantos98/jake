module jake

import os
import json
import utils
import java

pub fn load_project() utils.JakeProject {
	// 1. Decode jakefile.json present where the jake bin was called
	mut jake_proj := json.decode(utils.JakeProject, os.read_file('./jakefile.json') or {
		eprintln("Couldn't read jakefile in root folder.")
		exit(1)
	}) or {
		eprintln('> Failed to load project! ERROR: ${err}')
		exit(1)
	}

	// 2. Try to create the folder structure
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

	// 3. Populate the struct
	jake_proj.pwd = os.getwd()
	jake_proj.src_dir_path = './src/main'
	jake_proj.tests_dir_path = './src/tests'
	jake_proj.build_dir_path = './build/main'
	jake_proj.build_tests_dir_path = './build/tests'
	jake_proj.libs_dir_path = './libs'
	jake_proj.jar_name = '${jake_proj.name}-${jake_proj.version}.jar'
	jake_proj.sources = os.walk_ext(jake_proj.src_dir_path, 'java')
	jake_proj.libs = os.walk_ext(jake_proj.libs_dir_path, 'jar')

	// 4. Check if the project has tests enabled, and then setup for testing
	if jake_proj.include_testing {
		jake_proj.tests = os.walk_ext(jake_proj.tests_dir_path, 'java')
		setup_testing(jake_proj)
	}
	return jake_proj
}

fn setup_testing(jk utils.JakeProject) {
	// fixme 23/09/19: This should be replaced with global repositories later like maven or gradle.
	hamcrest_url := 'https://repo1.maven.org/maven2/org/hamcrest/hamcrest-core/${utils.hamcrest_version}/hamcrest-core-${utils.hamcrest_version}.jar'
	junit_url := 'https://repo1.maven.org/maven2/junit/junit/${utils.junit_version}/junit-${utils.junit_version}.jar'

	// 1. Check for existance of wget
	// fixme 23/09/19:
	// - /dev/null: Only checking for unix systems
	//				Use > NUL for windows.
	// - wget: Only unix systems has wget by default.
	// 	 	   From windows10+, microsoft include support for curl, this can be a option.			
	if os.system('wget --version > /dev/null 2>&1') != 0 {
		eprintln("> wget doesn't exist! jake relies on wget to download the necessary libraries.")
		exit(1)
	}

	// 2. Check for existance of junit and hamcrest and downloaded them if needed.
	if !os.exists('${jk.pwd}/.cache/junit-${utils.junit_version}.jar') {
		println('> JUnit not found. Downloading junit-${utils.junit_version}...')
		out, rc := utils.execute_in_dir('wget -q ${junit_url}', '${jk.pwd}/.cache/')
		os.wait()
		if rc > 0 {
			eprintln(out)
			exit(rc)
		}
		println('> Ok.')
	}

	if !os.exists('${jk.pwd}/.cache/hamcrest-core-${utils.hamcrest_version}.jar') {
		println('> Hamcrest not found. Downloading junit-${utils.junit_version}:')
		out, rc := utils.execute_in_dir('wget -q ${hamcrest_url}', '${jk.pwd}/.cache/')
		os.wait()
		if rc > 0 {
			eprintln(out)
			exit(rc)
		}
		println('> Ok.')
	}
}

pub fn build_project(run bool, args []string) {
	//1. Load project
	mut jake_proj := load_project()

	//2. Do java stuff
	java.compile_srcs(jake_proj)
	java.create_jar(jake_proj)

	//3. Move the built jar to the project root directory
	os.mv('${jake_proj.build_dir_path}/${jake_proj.jar_name}', '.') or {
		eprintln("Couldn't move final jar from build folder to the root of the project. ERR: ${err}")
		exit(1)
	}

	//4. Run the project if necessary
	if run {
		println('==========Running jar ${jake_proj.jar_name}==========')
		run_project(jake_proj, args)
	}
}

pub fn build_and_run_project_tests() {

	//1. Load project
	mut jake_proj := load_project()

	//2. Check if project includes testing
	if !jake_proj.include_testing {
		eprintln('> Jake option `include_testing` is false. Change it to true to include testing framework.')
		exit(1)
	}

	//3. Compile the tests
	java.compile_tests(jake_proj)

	//4. Run them
	println('=========Running tests==============================')
	run_tests(jake_proj)
}

pub fn run_project(jake_proj utils.JakeProject, args []string) {
	mut jar_args := ''
	for arg in args {
		jar_args += '${arg} '
	}

	mut cmd := 'java '

	if jake_proj.libs.len > 0 {
		cmd += '-cp .'
		for lib in jake_proj.libs {
			cmd += ':${lib}'
		}
		cmd += ':${jake_proj.jar_name} ${jake_proj.entry_point} ${jar_args}'
	} else {
		cmd += '-jar ${jake_proj.jar_name} ${jar_args}'
	}

	println('> ${cmd}')

	res := os.execute(cmd)
	print(res.output)
	if res.exit_code != 0 {
		eprintln('> Failed to run jar file.')
		exit(res.exit_code)
	}
}

fn run_tests(jk utils.JakeProject) {
	if !jk.include_testing {
		eprintln('> Jake option `include_testing` is false. Change it to true to include testing framework.')
		exit(1)
	}

	mut cmd := 'java -cp .:${jk.build_tests_dir_path}'

	for lib in jk.libs {
		cmd += ':${lib}'
	}

	cmd += ':.cache/junit-${utils.junit_version}.jar:.cache/hamcrest-core-${utils.hamcrest_version}.jar'

	cmd += ':${jk.jar_name} org.junit.runner.JUnitCore '

	for test in jk.tests {
		classpath := test.replace('${jk.tests_dir_path}/', '').replace('/', '.').replace('.java',
			'')
		cmd += '${classpath} '
	}

	println('> ${cmd}')

	res := os.execute(cmd)
	print(res.output)
	if res.exit_code > 0 {
		eprintln('> Failed to run tests.')
		exit(res.exit_code)
	}
}
