Cartridge Reflector
===================

A Sinatra Ruby app that that makes it easier to develop downloadable cartridges
by rewriting your manifest to include a Source-Url (which is what OpenShift uses
to get the cart data).

An example workflow might be:

1.  Create and upload a source GitHub repository corresponding to your cartridge
2.  Put your manifest.yml in metadata/

At this point, you wouldn't be able to download and test this cart on OpenShift 
without checking in a Source-Url.  If you changed the cart, you'd have to checkin
both a new manifest AND a new zip file (or host the zip file somewhere else). 
This would suck.  Fortunately.... the Cartridge Reflector can read your manifest
and automatically provide a Source-Url if you upload to GitHub!

3.  Craft a URL against my cart reflector http://cartreflect-claytondev.rhcloud.com/
(or stand up your own following the steps below)
 
        http://cartreflector-claytondev.rhcloud.com/reflect?github=<X>
        
    where <X> is the name of your user and repository, e.g. "smarterclayton/openshift-go-cart".
    If you hit the URL you'll see that the reflector generates a Source-Url that points
    back to GitHub.
    
4.  Pass that URL to rhc create-app to create a downloadable cart:

        rhc create-app foo http://cartreflector-claytondev.rhcloud.com/reflect?github=smarterclayton/openshift-go-cart

See the [root page of the reflector](http://cartreflector-claytondev.rhcloud.com/) for more documentation. It also supports relative URLs and GitHub commits (pass '&commit=<sha1>' when using the github param).

Setting up your own reflector
-----------------------------

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
