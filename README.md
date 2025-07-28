___  ___        _      _  _        ______              _               
|  \/  |       | |    (_)| |       |  _  \            | |              
| .  . |  ___  | |__   _ | |  ___  | | | | ___    ___ | | __ ___  _ __ 
| |\/| | / _ \ | '_ \ | || | / _ \ | | | |/ _ \  / __|| |/ // _ \| '__|
| |  | || (_) || |_) || || ||  __/ | |/ /| (_) || (__ |   <|  __/| |   
\_|  |_/ \___/ |_.__/ |_||_| \___| |___/  \___/  \___||_|\_\\___||_|   

# just-mobile-security-mobile-docker
This Docker aims to help to the Mobile Cybersecurity Community to have several Android and iOS Tools pre-configured.

This docker was tested for Ubuntu 22.04 and using the MASTG TOOLS (https://mas.owasp.org/MASTG/tools) as reference. Covering the Generic, Android, iOS and Network tools in case it applies.


The full list implemented is covered in the following documment https://docs.google.com/spreadsheets/d/10kHjVb7YZzyA_nzCAFTjtfaSZa9TnsAgILbttIPcYTE/edit?gid=1839499844#gid=1839499844 

How to run it?

* Docker configuration.

1. Download the git project.
2. Build the docker container.
2.1. sudo docker build -t just-mobile-security-mobile-docker .
3. Run the container
3.1. docker run -it --rm -v $(pwd):/workspace just-mobile-security-mobile-docker	

After that you only need to use the docker image as the following example.

$jadx


Additional tool implementations

Some additional tools were added to this docker image as Nuclei, disarm and more! These aren't within the OWASP Project (https://mas.owasp.org/MASTG/tools) if you want to add any additional tool, please create a PR for this repo with the tool and the instructions.
