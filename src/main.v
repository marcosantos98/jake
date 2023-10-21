module main

import cli { Command }
import jake
import os

// Usage:
// jake
//	Fast path to `jake build`
// jake build [options]
//	Build the current project
//	Options:
//		run <args> - Run the project after build with given args
// jake run <args>
//	Run the project
//		args - arguments passed to java
// jake test
//	Build and test
// jake sym
//	Create soft link to `/usr/local/bin`
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
						disable_flags: true
					},
				]
			},
			Command{
				name: 'run'
				description: 'Run project'
				usage: '<args>'
				execute: jake.run
				disable_man: true
				disable_flags: true
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
//  - Add `init` input driven command to setup new project
