require 'sinatra/base'
require 'httpclient'
require 'uri'
require 'safe_yaml'
require 'delegate'

class CartReflector < Sinatra::Base
  get '/' do
    headers 'Content-Type' => 'text/plain'
    <<-END
  This is the OpenShift cartridge reflector.  It will automatically rewrite cartridge
  manifests to include a relevant Source-Url for ease of debugging.  To use, pass the
  'u' parameter to the /reflect URI.

     #{request.scheme}://#{request.host_with_port}/reflect?u=https://url.to.my.server/path/of/my/manifest.yml

  You may also pass the 'github' parameter as '<user>/<project>' and the reflector will
  assume the 'metadata/manifest.yml' relative path is your cartridge manifest. If you
  specify 'commit', the reflector will use that commit directly.

     #{request.scheme}://#{request.host_with_port}/reflect?github=smarterclayton/openshift-go-cart&commit=master

  The reflector will attempt the following rewrites of the Source-Url in order:

  * If a fully qualified URL, return the manifest as-is (unless 'r=1' is passed)
  * If a relative path, relativize it to the manifest URL
  * If the manifest URL appears to be a raw GitHub file, use GitHub's archive zip function
  * If the manifest URL does not end with '/metadata/manifest.yml' or '/metadata/manifest.yaml', 
    rewrite the manifest URL to point to the same name with .tar.gz at the end

  Examples:

  Manifest URL           Source-Url                Outcome
  ------------           ----------                -------
  http://a.com/cart/foo  http://a.com/cart/bar.zip http://a.com/cart/bar.zip
   "                     bar.zip                   http://a.com/cart/bar.zip
   "                     --                        http://a.com/cart/foo.tar.gz

  http://github.com/me/project/raw/master/metadata/manifest.yml -> 
    https://github.com/me/project/archive/master.zip

  http://github.com/me/project/raw/3107eb65cccdeefbd7ea0622c7eab9a2249bf3f2/metadata/manifest.yml -> 
    https://github.com/me/project/archive/3107eb65cccdeefbd7ea0622c7eab9a2249bf3f2.zip

    END
  end

  get '/reflect' do
    headers 'Content-Type' => 'text/plain'

    if params[:github]
      url = URI.parse("https://raw.github.com/#{params[:github]}/#{params[:commit] || 'master'}/metadata/manifest.yml")
    else
      return [400, "Pass URL to reflect as parameter 'u'"] unless (url = params[:u]) && !url.empty?
      return [400, "Pass a valid URL"] unless url = URI.parse(url)
    end
    return [400, "Pass a URL with a scheme and a host"] unless url.host && url.scheme && url.path != '/reflect'

    c = HTTPClient.new

    # set limits on the incoming request
    c.read_block_size = 30*1024
    c.connect_timeout = 5
    c.send_timeout = 5
    c.receive_timeout = 5

    s = ""
    begin
      c.get_content(url) do |chunk|
        s << chunk
        return [400, "Manifest too long"] if s.length > c.read_block_size
      end
    rescue HTTPClient::BadResponseError => e
      return [400, "Manifest unreachable, #{e.res.code}"]
    end

    manifest = YAML.load(s, nil, :safe => true, :raise_on_unknown_tag => true) rescue (return [400, "Manifest could not be safely parsed"])
    source = URI.parse(manifest['Source-Url'] || '') rescue nil
    if (source && source.host) and not params[:r]
      puts "Manifest #{url} already has a source-url"
      headers 'X-OpenShift-Cartridge-Reflect' => 'unchanged'
      return s
    end

    if source
      source = UrlConditions.new(source)
      if source.relative_path?
        source = URI.join(url, source)
        puts "Joining relative path to manifest URL #{source}"

        manifest['Source-Url'] = source.to_s
        headers 'X-OpenShift-Cartridge-Reflect' => 'relative_path'
        return manifest.to_yaml.gsub(/\A---\n/,'')
      end
    end

    url = UrlConditions.new(url)

    if m = url.raw_github_project_manifest?
      puts "Matched github hosted raw manifest, user=#{m[1]} project=#{m[2]} commit=#{m[3]}"

      manifest['Source-Url'] = "https://github.com/#{m[1]}/#{m[2]}/archive/#{m[3]}.zip"
      headers 'X-OpenShift-Cartridge-Reflect' => 'github_archive'
      return manifest.to_yaml.gsub(/\A---\n/,'')
    end

    if not url.manifest_path?
      dir = File.dirname(url.path)
      name = File.basename(file, File.extname(file))

      url.path = "#{dir}/#{name}.tar.gz"
      puts "Generic path, assume #{url.path}"

      manifest['Source-Url'] = url.to_s
      headers 'X-OpenShift-Cartridge-Reflect' => 'rewrite_path'
      return manifest.to_yaml.gsub(/\A---\n/,'')
    end

    headers 'X-OpenShift-Cartridge-Reflect' => 'unchanged'
    s
  end

  class UrlConditions < SimpleDelegator
    def github?
      host == 'github.com'
    end
    def raw_github?
      host == 'raw.github.com'
    end
    def raw_github_project_manifest?
      (github? && %r|/([^/]+)/([^/]+)/raw/([^/]+)/metadata/manifest\.ya?ml\Z|.match(path)) ||
      (raw_github? && %r|/([^/]+)/([^/]+)/([^/]+)/metadata/manifest\.ya?ml\Z|.match(path))
    end
    def manifest_path?
      path.end_with?('/metadata/manifest.yml') || path.end_with?('/metadata/manifest.yaml')
    end
    def relative_path?
      not path.empty? and not path.start_with?('/')
    end
  end
end