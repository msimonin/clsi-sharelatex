Settings = require "settings-sharelatex"
spawn = require("child_process").spawn
logger = require "logger-sharelatex"

# Runs the compilation in a docker
#
# New settings are required : 
# clsi.commandRunner = './DockerRunner'
# clsi.uid 
# clsi.gid
# clsi.texliveRoot
#

TIMEOUT_EXIT_CODE=124
TIMEOUT_DEFAULT=60

module.exports = DockerRunner =
	run: (project_id, command, directory, image, timeout, callback = (error) ->) ->
		command = (arg.replace('$COMPILE_DIR', '/compile') for arg in command)
		clsiUid = Settings.clsi.uid
		clsiGid = Settings.clsi.gid
		image = Settings.clsi.image
		# override the use of the timeout 
		# -> The timeout isn't a user feature
		localTimeout = Settings.clsi.timeout || TIMEOUT_DEFAULT

		# we encapsulate the command in a docker command
		# we share the texlive installation in read only
		# we share the compile directory
		docker = [
			"timeout",
			localTimeout,
			"docker",
			"run",
            "--rm",
			"--label", "sharelatex.project_id=#{project_id}",
			"-v","#{directory}:/compile",
    			"#{image}",
		  	"sudo", "-g", "\##{clsiGid}", "-u", "\##{clsiUid}"
			]

		# we append the command to run to the docker one
		command = docker.concat(command)
		logger.log project_id: project_id, command: command, directory: directory, "running command"

		proc = spawn command[0], command.slice(1), stdio: "inherit", cwd: directory
		proc.on "close", (code) ->
			if (code == TIMEOUT_EXIT_CODE)
				console.log("TIMED OUT", code);
				error = {timedout: true}
			callback(error)
