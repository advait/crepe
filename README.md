Crepe
=====

Node.js Gnutella client written in CoffeeScript.
It doesn't get more hipster than this.

Authors
=======
- Advait Shinde
- Kevin Nguyen
- Mark Vismonte

## Installation (Mac)
Install Xcode
  Go to https://developer.apple.com/technologies/tools to download and install Xcode
Install Git:
  Go to http://git-scm.com to download and install the latest Mac version of Git

Installing node:
  $ git clone git://github.com/ry/node.git
  $ cd node
  $ ./configure
  $ make
  $ sudo make install

## Installation (Ubuntu)
Install the dependencies:

  * sudo apt-get install g++ curl libssl-dev apache2-utils
  * sudo apt-get install git-core

Run the following commands to install node:

  $ git clone git://github.com/ry/node.git
  $ cd node
  $ ./configure
  $ make
  $ sudo make install

## Running Gnutella Client
Simply run the following command in the root folder of the source code.

  $ node crepe.js

You should see a prompt similar to the following:

  $ Static Files hosting on localhost:51922
  $ crepe>> server is now listening port 51923
  $ CTRL+C to exit

Type "help" and then enter to see a list of valid commands:

  connect <ip_address> <port>
  search <search_term>
  list
  neighbors
  download <file_id>
  debug
  nodebug

## Connecting to a boostrap node
On a different terminal you can run the exact same command again to start
another node.

  $ node crepe.js

This time you can connect to the already running node by typing:

  connect 51923

Be sure to replace 51923 with the listening port of the first node that was
already started.

## Searching for content
Next, you can search for specific files to download. Try searching for this
README.md file.

  search README.md

A result will probably display showing something like:

  #0 filename:README.md, size:1675, index:79590453, serventID:0123456789abcdef

You can search for other files as well such as crepe.js:

  search crepe.js

## Downloading content
To display a list of current hits, you can type "list" which will display:

  #0 filename:README.md, address:127.0.0.1, port:51922,
  #1 filename:crepe.js, address:127.0.0.1, port:51922,

If there are more than one result, they  will be identified by their preceding
id number. To download this particiular README.md file enter:

  download 0

This will download the README.md file into the same directory. A duplicate
README.md file will be downloaded called README_(0).md

To download the crepe.js file, you can type:

  download 1
