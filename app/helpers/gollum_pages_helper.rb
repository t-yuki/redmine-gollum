require 'uri'
module GollumPagesHelper
    def gollum_include_ckeditor(field_id)
    	return '' if ! @project.gollum_wiki.use_ckeditor; 
    	ckeditor_include + ckeditor(field_id)
    end

    def ckeditor_include
	javascript_include_tag('ckeditor/ckeditor', :plugin => 'redmine_ckeditor')
    end

    def ckeditor(field_id)
    	url = url_for(
		:controller => 'gollum_pages',
		:action => 'upload',
		:authenticity_token => form_authenticity_token)

	javascript_tag <<-EOT
		CKEDITOR.replace('#{field_id}', {
		   filebrowserImageUploadUrl : '#{url}',
		});
		CKEDITOR.config.height='500px';
	EOT
    end
end
