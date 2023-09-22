module main

import os
import jake

fn print_usage() {
	println('Usage:')
	println('\tjake [options]')
	println('\tOptions:')
	println('\t\t-br: Build and run the jar program.')
	println('\t\t-bt: Build and run the tests with JUnit.')
	println('\t\t-r: Run the jar program.')
	println('\t\t-v: Print the version.')
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
			'-h' {
				print_usage()
			}
			'-br' {
				jake.build_project(true, collect_args())
			}
			'-bt' {
				jake.build_and_run_project_tests()
			}
			'-r' {
				jk := jake.load_project()
				jake.run_project(jk, collect_args())
			}
			'-v' {
				println('jake 0.0.1')
			}
			else {
				print_usage()
			}
		}
	} else {
		jake.build_project(false, [])
	}
}

// TODO:
//	- Add include folders and files with filter options like "*".
// 	- Fat jar support.
//	- Check for existance of javac and jar.
//	- Add option to remove verbose output.
//  - Include more documentation in code.
//  - Improve command generation
//  - Improve logging
//  - Fix Inner class not being deleted if not needed
