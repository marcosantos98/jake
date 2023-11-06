module main

import benchmark
import cli { Command }
import jake
import os
import utils { if_bench }

// Usage:
// jake
//	Fast path to `jake build`
// jake init
//  Create jakefile.json with user input and setup project structure
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
	mut b := benchmark.start()
	mut app := Command{
		name: 'jake'
		description: 'Compile the current project in the working directory.\n- Get started with `jake init`\n- Know more with `jake help`\n- You can use `jake` as a shortcut to `jake build`'
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
				name: 'init'
				description: 'Initialize sample project.'
				execute: jake.init
				disable_man: true
				disable_flags: true
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
	if_bench(mut b, 'Setup cli commands')
	app.parse(os.args)
	if_bench(mut b, 'Parse cli commands')
}

// TODO:
//	- Add include folders and files with filter options like "*".
// 	- Fat jar support.
//	- Add option to remove verbose output.
