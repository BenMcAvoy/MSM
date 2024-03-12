# MSM - Minecraft Server Manager

MSM is a Minecraft server manager that makes it easy to manage your server. It's a simple bash script that can be run on any server, even a Raspberry Pi, and it's easy to set up and use! It's also a great alternative to the Minecraft server hosting services, which are often expensive and offer limited control over your server.

## Usage
- Simply run `msm` and it will run create a proxy and lobby server.
- Run `msm new <server_name> <type>` to create a new server.
- Example: `msm new proxy2 velocity` will create another proxy, not sure you would need this but it's possible.
- Example: `msm new survival paper` will create a new vanilla server called "survival".
- Example: `msm new modded fabric` will create a new fabric server called "survival".
