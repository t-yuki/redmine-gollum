resources :projects do
  get   'gollum_list' => 'gollum_pages#list'
  match 'gollum_upload'  => 'gollum_pages#upload'
  get   'gollum_files/:id'  => 'gollum_pages#file', constraints: { id: /.+/ }
  get   'gollum_pages/:id/raw'  => 'gollum_pages#raw'
  resources :gollum_pages do
    collection do
      post 'preview'
    end
  end
  resource :gollum_wiki
end
