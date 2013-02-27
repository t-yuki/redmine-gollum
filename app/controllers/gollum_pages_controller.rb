require_dependency 'user'

# A controller used to view and edit wiki pages.
class GollumPagesController < ApplicationController
  unloadable

  before_filter :find_project, :find_wiki
  before_filter :authorize, :except => [ :preview ]

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

#    map = @wiki.tree_map_for(@wiki.ref)
#    all =''
#    map.each do |entry|
#    	#all = all + ',' + entry.dir + '/' + entry.name
#    	all = all + ',' + entry.path.downcase
#    end
#    if entry = map.detect { |entry| entry.path.downcase == 'file/' + @file_name }
#    	all = 'NASEL JSEM' + entry.path
#    end
#


  def file 
    ext = params[:ext]
    @file_name = params[:id] + '.' + ext
    dir =  @wiki.page_file_dir
    mime_type = Mime::Type.lookup_by_extension(ext) || 'text/plain'

    if file = @wiki.file(File.join(dir, @file_name))
       name = file.name
       url = file.url_path
       # FIXME: content-type has 'charset=utf8' why?
       render :text => file.raw_data, :content_type=> mime_type
    else
      render :status => 404, :inline => '404 not found:dir:' + dir +',file:' + @file_name 
      return
    end
  end

  # <form><input type=file name=upload[datafile]>
  def upload 
    if request.get?
    	# render upload.html.erb
    	return
    end

    # post

    @user = User.current
    upload = params[:file]
    name = upload.original_filename
    data = upload.read
    dir =  @wiki.page_file_dir
    write_file(dir, name, data)
    #render :inline => 'diky:' + name
    flash[:notice] = name + ' uploaded'
    redirect_to :action => :upload
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
    @content = @page ? @page.text_data : ""
    @page_format = @page ? @page.format : @project.gollum_wiki.markup_language.to_sym
  end

  def update
    @page_name = params[:id]
    @page_format = params[:page][:format].to_sym
    @page = @wiki.page(@page_name)
    @user = User.current

    commit = { :message => params[:page][:message], :name => @user.name, :email => @user.mail }

    if @page
      @wiki.update_page(@page, @page.name, @page_format, params[:page][:raw_data], commit)
    else
      @wiki.write_page(@page_name, @page_format, params[:page][:raw_data], commit)
    end

    redirect_to :action => :show, :id => @page_name
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
                            :page_file_dir => wiki_dir)

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
