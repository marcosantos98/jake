module main

import cli { Command }
import jake
import os

fn print_usage() {
	println('Usage:')
	println('\tjake [options]')
	println('\tOptions:')
	println('\t\t-br: Build and run the jar program.')
	println('\t\t-bt: Build and run the tests with JUnit.')
	println('\t\t-r: Run the jar program.')
	println('\t\t-v: Print the version.')
}

fn collect_args() string {
	mut args := ''
	if os.args.len > 2 {
		for i in 2 .. os.args.len {
			args += '${os.args[i]} '
		}
	}
	return args
}

fn main() {
	mut app := Command{
		name: 'jake'
		execute: jake.build
		disable_man: true
		commands: [
			Command{
				name: 'build'
				description: 'Build the project'
				execute: jake.build
				disable_man: true
				commands: [
					Command{
						name: 'run'
						description: 'Run after the build is finished'
						usage: '<args>'
						execute: jake.buildrun
						disable_man: true
					},
				]
			},
			Command{
				name: 'run'
				description: 'Run project'
				usage: '<args>'
				execute: jake.run
				disable_man: true
			},
			Command{
				name: 'test'
				description: 'Prepare and run tests'
				execute: jake.test
				disable_man: true
			},
		]
	}

	app.setup()
	app.parse(os.args)
}

// TODO:
//	- Add include folders and files with filter options like "*".
// 	- Fat jar support.
//	- Add option to remove verbose output.
//  - Include more documentation in code.
//  - Improve command generation
//  - Fix Inner class not being deleted if not needed
