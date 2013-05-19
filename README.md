Cartridge Reflector
===================

A Sinatra Ruby app that will automatically rewrite OpenShift cartridge manifests
to have a Source-Url.  Cartridges in a repository in GitHub (using the standard)
format can easily be rewritten to use GitHub's archive download function.  Can 
also rewrite relative Source-Url's to point to a file in the same directory but
with the .tar.gz extension.

You can provide the full reflector URL as a downloadable cartridge to OpenShift,
so you don't have to check your Source-Url binary directly into your source 
repository and change the manifest.


Usage
-----

Check the repository out, and from the root directory run:

    bundle install

to install the necessary dependencies.  Then run:

    bundle exec rackup

to start the embedded server on port 9292.  Then hit the server in your browser:

    http://localhost:9292/

to see the documentation.  To actually reflect a cart URL, use the 'u' or 'github' 
parameters.

    http://localhost:9292/reflect?github=smarterclayton/openshift-go-cart

will load the cartridge manifest on GitHub for user *smarterclayton*, project *openshift-go-cart*, and with the relative directory *metadata/manifest.yml*.  If it finds and can
load the manifest (normal size and parsing restrictions apply), it will rewrite the 
Source-Url in the manifest to 

    https://github.com/smarterclayton/openshift-go-cart/archive/master.zip

and then return the manifest.  You'll need to host this app where OpenShift can talk to it (why not [host it on OpenShift?](https://openshift.redhat.com/app/console/application_types/custom?cartridges=ruby-1.9&initial_git_url=git://github.com/smarterclayton/cartridge-reflector.git)), but once you've done that just paste the reflected cart URL directly into the OpenShift console.

You can use my public reflector at http://cartreflect-claytondev.rhcloud.com/ on OpenShift.