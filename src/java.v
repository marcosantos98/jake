module java

import os
import term { reset }
import utils { log, log_error }

pub fn compile_srcs(jake utils.JakeProject) {
	mut classpath := '-cp ${jake.build_dir_path}'

	for lib in jake.libs {
		classpath += ':${lib}'
	}

	mut sources := ''

	for source in jake.sources {
		built_source := source.replace(jake.src_dir_path, jake.build_dir_path).replace('.java',
			'.class')
		if !os.exists(built_source)
			|| os.file_last_mod_unix(source) > os.file_last_mod_unix(built_source) {
			sources += '${source} '
		}
	}

	if sources == '' {
		println('> Nothing to build.')
		return
	}

	options := '${classpath} -d ${jake.build_dir_path}'
	cmd := 'javac ${options} ${sources}'

	log('> Compile java files with javac:')
	println(reset('\t${cmd}'))

	res := os.execute(cmd)
	print(res.output)
	if res.exit_code != 0 {
		log_error('> Failed compilation step.')
		exit(res.exit_code)
	}
}

pub fn compile_tests(jake utils.JakeProject) {
	mut classpath := '-cp ${jake.build_dir_path}:${jake.build_tests_dir_path}:./.cache/junit-${utils.junit_version}.jar:./.cache/hamcrest-core-${utils.hamcrest_version}.jar'

	for lib in jake.libs {
		classpath += ':${lib}'
	}

	mut sources := ''

	for test in jake.tests {
		built_test := test.replace(jake.tests_dir_path, jake.build_tests_dir_path).replace('.java',
			'.class')
		if !os.exists(built_test) || os.file_last_mod_unix(test) > os.file_last_mod_unix(built_test) {
			sources += ' ${test}'
		}
	}

	if sources == '' {
		println('> Nothing to build.')
		return
	}

	options := '${classpath} -d ${jake.build_tests_dir_path}'
	cmd := 'javac ${options} ${sources}'

	log('> Compile java test files with javac:')
	println(reset('\t${cmd}'))
	res := os.execute(cmd)
	print(res.output)
	if res.exit_code != 0 {
		log_error('> Failed compilation step.')
		exit(res.exit_code)
	}
}

pub fn create_jar(jake utils.JakeProject) {
	// 1. Cleanup old .class files that don't exist in .java form.
	for built_source in os.walk_ext(jake.build_dir_path, 'class') {
		src := built_source.replace('.class', '.java').replace(jake.build_dir_path, jake.src_dir_path)
		if built_source.contains('$') {
			if !os.exists(src.split('$')[0] + '.java') {
				os.rm(built_source) or { panic('${err}') }
			}
		} else {
			if !os.exists(src) {
				os.rm(built_source) or { panic('${err}') }
			}
		}
	}

	// 2. Check for entry point, if present include `e` option
	mut options := if jake.entry_point != '' {
		'cfe ${jake.jar_name} ${jake.entry_point} *'
	} else {
		'cf ${jake.jar_name} *'
	}

	// 3. Call exec with the generated command: jar ${options}
	cmd := 'jar ${options}'
	log('> Creating jar file ${jake.jar_name}:')
	println(reset('\t${cmd}'))
	out, _ := utils.execute_in_dir(cmd, jake.build_dir_path)
	print(out)
}
