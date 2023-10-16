module main

import cli { Command }
import jake
import os

// Usage:
// jake [flags]
// jake build [options]
//	Build the current project
//	Options:
//		run - Run the project after build
// jake run
//	Run the project
// jake test
//	Build and test
// jake sym
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
			Command{
				name: 'sym'
				description: 'Create soft link to the jake executable'
				execute: jake.sym
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
