module utils

import benchmark
import os
import term

pub struct JakeProject {
pub:
	name            string   [required]
	version         string   [required]
	entry_point     string
	include_testing bool
	repos           []string
	deps            []string
pub mut:
	src_dir_path         string   [skip]
	build_dir_path       string   [skip]
	build_tests_dir_path string   [skip]
	libs_dir_path        string   [skip]
	tests_dir_path       string   [skip]
	sources              []string [skip]
	tests                []string [skip]
	libs                 []string [skip]
	pwd                  string   [skip]
	jar_name             string   [skip]
	did_build            bool     [skip]
}

pub const (
	junit_version    = '4.13.2'
	hamcrest_version = '1.3'
)

// Measure if `-d bench` option is defined
pub fn if_bench(mut b benchmark.Benchmark, msg string) {
	$if bench ? {
		b.measure(msg)
	}
}

// Kinda copied and pasted from https://github.com/vlang/v/blob/master/examples/process/process_stdin_trick.v
pub fn execute_in_dir(cmd string, workind_dir string) (string, int) {
	mut cmd2 := cmd
	mut out := ''
	mut line := ''
	mut rc := 0
	// fixme 23/09/19: Doesn't work on windows.
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

	p.wait()
	p.close()
	if p.code > 0 {
		rc = 1
	}

	return out, rc
}

pub fn make_dir(name string) {
	if !os.exists(name) {
		os.mkdir(name) or {
			eprintln("Couldn't create folder. ERR: ${err}")
			exit(1)
		}
	}
}

pub fn check_tool(tool string) {
	// 1. Check for existance of wget
	// fixme 23/09/19:
	// - /dev/null: Only checking for unix systems
	//				Use > NUL for windows.
	// - wget: Only unix systems has wget by default.
	// 	 	   From windows10+, microsoft include support for curl, this can be a option.
	if os.system('${tool} --version > /dev/null 2>&1') != 0 {
		log_error("> ${tool} doesn't exist! jake needs ${tool} to work.")
		exit(1)
	}
}

pub fn log_info(msg string) {
	println(term.bright_blue(msg))
}

pub fn log(msg string) {
	println(term.bright_green(msg))
}

pub fn log_error(msg string) {
	eprintln(term.bright_red(msg))
}

[noreturn]
pub fn log_fatal(msg string) {
	eprintln(term.bright_red(msg))
	exit(1)
}
