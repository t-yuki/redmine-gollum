require_dependency 'user'

# A controller used to view and edit wiki pages.
class GollumPagesController < ApplicationController
  unloadable

  before_filter :find_project, :find_wiki
  before_filter :authorize, :except => [ :preview ]

  # FIXME: rid off stupid gollum prewiki wikiing
  # wtf?  wtF? why?
  # dirty hack
  class MyMarkup < Gollum::Markup
    def render(no_follow = false, encoding = nil)
      data = @data.dup
      begin
        data = GitHub::Markup.render(@name, data)
        if data.nil?
          raise "There was an error converting #{@name} to HTML."
        end
      rescue Object => e
        data = %{<p class="gollum-error">#{e.message}</p>}
      end
      data
    end
  end

  class MyGollumFile < Gollum::File
    # Find a file in the given Gollum repo.
    #
    # name    - The full String path.
    # version - The String version ID to find.
    #
    # Returns a Gollum::File or nil if the file could not be found.
    def find(name, version)
      checked = name.downcase
      map     = @wiki.tree_map_for(version, true)
      if entry = map.detect { |entry| entry.path.downcase == checked }
        @path    = name
        @blob    = entry.blob(@wiki.repo)
        @version = version.is_a?(Grit::Commit) ? version : @wiki.commit_for(version)
        self
      end
    end
  end

  def index
    redirect_to :action => :show, :id => "Home"
  end

  def preview
    get_html(params[:raw_data], params[:page_format])
  end

  def show
    @editable = true

    show_page(params[:id])
  end

  def file 
    ext = params[:ext]
    @file_name = params[:id] + '.' + ext
    dir =  @project.gollum_wiki.images_directory
    mime_type = Mime::Type.lookup_by_extension(ext) || 'text/plain'

    if file = @wiki.file(File.join(dir, @file_name))
    #if file = file_search(File.join(dir, @file_name))
       name = file.name
       url = file.url_path
       # FIXME: content-type has 'charset=utf8' why?
       render :text => file.raw_data, :content_type=> mime_type
    else
      render :status => 404, :inline => '404 not found:dir:' + dir +',file:' + @file_name 
      return
    end
  end

  def file_search(path, version = @wiki.ref)
    file = @wiki.file_class.new(@wiki)
    map  = @wiki.tree_map_for(version, true)

    if entry = map.detect { |entry| entry.path.downcase == path }
        file.path    = path
        file.blob    = entry.blob(@wiki.repo)
        file.version = version.is_a?(Grit::Commit) ? version : @wiki.commit_for(version)
        self
    end

  end

  # <form><input type=file name=upload[datafile]>
  def upload 
    if request.get?
        # render upload.html.erb
        return
    end



    @user = User.current
    upload = params[:upload]
    name = upload.original_filename
    data = upload.read
    #dir =  @wiki.page_file_dir
    dir = @project.gollum_wiki.images_directory
    
    write_file(dir, name, data)
    
    # FIXME:XSS
    ckeditor_num = params[:CKEditorFuncNum]
    script =  <<-EOT
    <script type="text/javascript">window.parent.CKEDITOR.tools.callFunction(#{ckeditor_num}, 'img/#{name}', '');</script>
    EOT
    if ckeditor_num
        render :inline => script
        #Rails.logger.fatal 'script rednered:' + script
        return
    else
        flash[:notice] = name + ' uploaded'
        redirect_to :action => :upload
        return
    end
  end
  
  def newpage
     return
  end

  def write_file(dir, name, data)

    message = 'write file ' + name
    commit = { :message => message, :name => @user.name, :email => @user.mail }
    commiter = Gollum::Committer.new(@wiki, commit)

    path = File.join(dir, name)
    path = path[1..-1] if path =~ /^\//

    commiter.index.add(path, data)
    commiter.commit
    @wiki.clear_cache

    # fixme: do it if not bare
    #commiter.update_working_dir( ... )
  end

  def edit
    @page_name = params[:id]
    @page = @wiki.page(@page_name)

    if @page
        @page_format = @page.format
    else
        @page_format = @project.gollum_wiki.markup_language.to_sym
    end
  end

  def list
    @pages = @wiki.pages
    tree = @wiki.tree_map_for(@wiki.ref, true)
    dir = @project.gollum_wiki.images_directory
    entries = tree.select { |e| e.path.index(dir) == 0 }
    @files = entries.map { |e| e.path }
  end

  def update
    @page_name = params[:id]
    @page_format = params[:page][:format].to_sym
    @page = @wiki.page(@page_name)
    @user = User.current

    commit = { :message => params[:page][:message], :name => @user.name, :email => @user.mail }

    # zkonvertuj html -> wiki if needed
    if @project.gollum_wiki.store_as_wiki
      data = params[:page][:formatted_data]
      data = ReverseMarkdown.parse data
    else
      data = params[:page][:raw_data]
    end

    if @page
      @wiki.update_page(@page, @page.name, @page_format, data, commit)
    else
      @wiki.write_page(@page_name, @page_format, data, commit)
    end

    redirect_to :action => :show, :id => @page_name
  end

  def raw
    name = params[:id]
    if page = @wiki.page(name)
      render :text => page.raw_data, :content_type => 'text/plain'
    else
      render :status => 404, :inline => '404 not found:' + name
      return
    end
  end

  private

  def project_repository_path
    return @project.gollum_wiki.git_path
  end


  def show_page(name)
    if page = @wiki.page(name)
      @page_name = page.name
      @page_title = page.title
      @page_content = page.formatted_data.html_safe
    else
      redirect_to :action => :edit, :id => name
    end
  end

  def find_project
    unless params[:project_id].present?
      render :status => 404
      return
    end

    @project = Project.find(params[:project_id])
  end

  def find_wiki
    git_path = project_repository_path
    # TODO git_path should never be empty

    unless File.directory? git_path
      Grit::Repo.init_bare(git_path)
    end

    wiki_dir = @project.gollum_wiki.directory
    if wiki_dir.empty?
      wiki_dir = nil
    end

    gollum_base_path = project_gollum_pages_path
    @wiki = Gollum::Wiki.new(git_path,
                            :base_path => gollum_base_path,
                            :page_file_dir => wiki_dir,
                            :file_class=>::GollumPagesController::MyGollumFile,
                            :markup_classes => Hash.new(::GollumPagesController::MyMarkup))

  end

  def get_html(data, format)
    if data.nil? || format.nil?
      html = ''
    else
      html = @wiki.preview_page('temp', data, format).formatted_data.html_safe
    end
    render :inline => html
  end
end
