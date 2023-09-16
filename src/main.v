module main

import os
import json

struct JakeProject {
	name           string [required]
	version        string [required]
	src_dir_path   string [required]
	build_dir_path string [required]
	libs_dir_path  string [required]
	entry_point    string
mut:
	sources  []string [skip]
	libs     []string [skip]
	pwd      string   [skip]
	jar_name string   [skip]
}

// Kinda copied and pasted from https://github.com/vlang/v/blob/master/examples/process/process_stdin_trick.v
fn exec(cmd string, workind_dir string) (string, int) {
	mut cmd2 := cmd
	mut out := ''
	mut line := ''
	mut rc := 0
	mut p := os.new_process('/bin/bash')
	p.set_work_folder(workind_dir)

	p.set_args(['-c', 'bash 2>&1'])
	p.set_redirect_stdio()
	p.run()

	p.stdin_write('${cmd2} && echo **OK**')
	os.fd_close(p.stdio_fd[0]) // important: close stdin so cmd can end by itself

	for p.is_alive() {
		line = p.stdout_read()
		out += line
		if line.ends_with('**OK**\n') {
			out = out[0..(out.len - 7)]
			break
		}
	}

	out += p.stdout_read()

	p.close()
	p.wait()
	if p.code > 0 {
		rc = 1
	}

	return out, rc
}

fn java_compile_srcs(jake JakeProject) {
	if jake.sources.len == 0 {
		exit(1)
	}

	mut classpath := '-cp ${jake.build_dir_path}'

	for lib in jake.libs {
		classpath += ':${lib}'
	}

	mut options := '${classpath} -d ${jake.build_dir_path}'
	mut sources := ''
	for source in jake.sources {
		built_source := source.replace(jake.src_dir_path, jake.build_dir_path).replace('.java',
			'.class')
		if !os.exists(built_source)
			|| os.file_last_mod_unix(source) > os.file_last_mod_unix(built_source) {
			sources += ' ${source}'
		}
	}

	if sources == '' {
		println('> Nothing to build.')
		return
	}

	cmd := 'javac ${options} ${sources}'

	println('> Compile java files with javac:\n\t${cmd}')

	out, _ := exec(cmd, '.')
	print(out)
}

fn java_create_jar(jake JakeProject) {
	mut options := if jake.entry_point != '' {
		'cfe ${jake.jar_name} ${jake.entry_point} *'
	} else {
		'cf ${jake.jar_name} *'
	}

	cmd := 'jar ${options}'
	println('> Creating jar file ${jake.jar_name}:\n\t${cmd}')
	out, _ := exec(cmd, jake.build_dir_path)
	print(out)
}

fn print_usage() {
	println('Usage:')
	println('\tjake [options]')
	println('\tOptions:')
	println('\t\t-b: Only build.')
	println('\t\t-br: Build and run the jar program.')
	println('\t\t-r: Run the jar program.')
	println('\t\t-v: Print the version.')
}

fn load_project() JakeProject {
	data := os.read_file('./jakefile.json') or {
		eprintln("Couldn't read jakefile in root folder.")
		exit(1)
	}
	mut jake_proj := json.decode(JakeProject, data) or {
		eprintln('> Failed to load project! ERROR: ${err}')
		exit(1)
	}
	jake_proj.sources = os.walk_ext(jake_proj.src_dir_path, 'java')
	jake_proj.libs = os.walk_ext(jake_proj.libs_dir_path, 'jar')
	jake_proj.pwd = os.getwd()
	jake_proj.jar_name = '${jake_proj.name}-${jake_proj.version}.jar'

	return jake_proj
}

fn build_project(run bool, args []string) {
	mut jake_proj := load_project()

	java_compile_srcs(jake_proj)
	java_create_jar(jake_proj)

	os.mv('${jake_proj.build_dir_path}/${jake_proj.jar_name}', '.') or {
		eprintln("Couldn't move final jar from build folder to the root of the project. ERR: ${err}")
		exit(1)
	}

	if run {
		println('==========Running jar ${jake_proj.jar_name}==========')
		run_project(jake_proj, args)
	}
}

fn run_project(jake_proj JakeProject, args []string) {
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

	out, _ := exec(cmd, '.')
	print(out)
}

fn collect_args() []string {
	mut args := []string{}
	if os.args.len > 2 {
		for i in 2 .. os.args.len {
			args << os.args[i]
		}
	}
	return args
}

fn main() {
	if os.args.len >= 2 {
		match os.args[1] {
			'-b' {
				build_project(false, [])
			}
			'-br' {
				build_project(true, collect_args())
			}
			'-r' {
				jake := load_project()
				run_project(jake, collect_args())
			}
			'-v' {
				println('jake 0.0.1')
			}
			else {
				print_usage()
			}
		}
	} else {
		print_usage()
		exit(1)
	}
}

// TODO:
//	- Add include folders and files with filter options like "*".
// 	- Fat jar support.
//	- Check for existance of javac and jar.
//	- Add option to remove verbose output.
//	- Add option to set the test entrypoint
