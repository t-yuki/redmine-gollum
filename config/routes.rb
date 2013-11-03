resources :projects do
  match 'img/:id.:ext' => 'gollum_pages#file'
  match 'gollum_pages/img/:id.:ext' => 'gollum_pages#file'
  match 'list' => 'gollum_pages#list'

  get   'newpage' => 'gollum_pages#newpage'
  post  'newpage' => 'gollum_pages#edit'
  match 'upload'  => 'gollum_pages#upload', :as => :upload
  get   'gollum_pages/:id/raw'  => 'gollum_pages#raw', :as => :raw
  resources :gollum_pages do
    collection do
      post 'preview'
    end
  end
  resource :gollum_wiki
end
