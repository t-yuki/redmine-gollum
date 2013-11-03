class CkeditorToGollumWikis < ActiveRecord::Migration
  def self.up
    add_column :gollum_wikis, :use_ckeditor, :boolean, :default => 0
    add_column :gollum_wikis, :store_as_wiki, :boolean, :default => 0
    add_column :gollum_wikis, :images_directory, :string, :default => 'img'
  end

  def self.down
    remove_column :gollum_wikis, :use_ckeditor
    remove_column :gollum_wikis, :store_as_wiki
    remove_column :gollum_wikis, :images_directory
  end
end
