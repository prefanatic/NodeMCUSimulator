bash moonc "/mnt/c/Users/Cody Goldberg/IdeaProjects/NodeMCUSimulatorPrefan/init.moon"
chdir /d "C:\Users\Cody Goldberg\"
python nodemcu-uploader\nodemcu-uploader.py --port COM3 upload "IdeaProjects\NodeMCUSimulatorPrefan\init.lua":init.lua
::python nodemcu-uploader\nodemcu-uploader.py --port COM3 upload "IdeaProjects\NodeMCUSimulatorPrefan\laundry.lua":application.lua