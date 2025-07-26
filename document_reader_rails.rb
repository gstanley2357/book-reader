# Gemfile
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.0'

gem 'rails', '~> 7.0.0'
gem 'sqlite3', '~> 1.4'
gem 'puma', '~> 5.0'
gem 'sass-rails', '>= 6'
gem 'webpacker', '~> 5.0'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'jbuilder', '~> 2.7'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'pdf-reader'
gem 'nokogiri'
gem 'image_processing', '~> 1.2'

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  gem 'web-console', '>= 4.1.0'
  gem 'listen', '~> 3.3'
  gem 'spring'
end

# ====================
# MODELS
# ====================

# app/models/document.rb
class Document < ApplicationRecord
  has_many :document_outlines, dependent: :destroy
  has_many :selected_texts, dependent: :destroy
  has_many :document_locations, dependent: :destroy
  
  validates :title, presence: true
  validates :content_type, presence: true, inclusion: { in: %w[text pdf webpage] }
  
  def outline_tree
    # TODO: Build hierarchical outline structure
  end
  
  def extract_text
    # TODO: Extract text based on content_type
  end
end

# app/models/document_outline.rb
class DocumentOutline < ApplicationRecord
  belongs_to :document
  belongs_to :parent, class_name: 'DocumentOutline', optional: true
  has_many :children, class_name: 'DocumentOutline', foreign_key: 'parent_id'
  
  validates :title, presence: true
  validates :level, presence: true, numericality: { greater_than: 0 }
  
  scope :root_level, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position) }
end

# app/models/selected_text.rb
class SelectedText < ApplicationRecord
  belongs_to :document
  has_many :definitions, dependent: :destroy
  has_many :links, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :synonyms, dependent: :destroy
  has_many :document_locations, dependent: :destroy
  
  validates :text, presence: true, uniqueness: true
  validates :text_type, presence: true
  
  def all_synonyms
    synonyms.pluck(:synonym_text) + [text]
  end
  
  def shared_data
    # TODO: Aggregate data from all synonyms
  end
end

# app/models/definition.rb
class Definition < ApplicationRecord
  belongs_to :selected_text
  
  validates :content, presence: true
  validates :context, presence: true
end

# app/models/link.rb
class Link < ApplicationRecord
  belongs_to :selected_text
  
  validates :url, presence: true
  validates :title, presence: true
end

# app/models/note.rb
class Note < ApplicationRecord
  belongs_to :selected_text
  
  validates :content, presence: true
end

# app/models/synonym.rb
class Synonym < ApplicationRecord
  belongs_to :selected_text
  
  validates :synonym_text, presence: true
end

# app/models/document_location.rb
class DocumentLocation < ApplicationRecord
  belongs_to :document
  belongs_to :selected_text
  
  validates :start_position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :end_position, presence: true, numericality: { greater_than: :start_position }
end

# ====================
# CONTROLLERS
# ====================

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
end

# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit, :update, :destroy]
  
  def index
    @documents = Document.all
  end
  
  def show
    @outline = @document.outline_tree
    @selected_text = params[:selected_text_id] ? SelectedText.find(params[:selected_text_id]) : nil
  end
  
  def new
    @document = Document.new
  end
  
  def create
    @document = Document.new(document_params)
    
    if @document.save
      # TODO: Process document content
      redirect_to @document, notice: 'Document was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @document.update(document_params)
      redirect_to @document, notice: 'Document was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @document.destroy
    redirect_to documents_url, notice: 'Document was successfully deleted.'
  end
  
  private
  
  def set_document
    @document = Document.find(params[:id])
  end
  
  def document_params
    params.require(:document).permit(:title, :content_type, :file_path, :url, :content)
  end
end

# app/controllers/selected_texts_controller.rb
class SelectedTextsController < ApplicationController
  before_action :set_selected_text, only: [:show, :edit, :update, :destroy]
  before_action :set_document
  
  def create
    @selected_text = @document.selected_texts.build(selected_text_params)
    
    if @selected_text.save
      render json: { success: true, selected_text: @selected_text }
    else
      render json: { success: false, errors: @selected_text.errors }
    end
  end
  
  def show
    render json: {
      selected_text: @selected_text,
      definitions: @selected_text.definitions,
      links: @selected_text.links,
      notes: @selected_text.notes,
      synonyms: @selected_text.synonyms,
      locations: @selected_text.document_locations
    }
  end
  
  def update
    if @selected_text.update(selected_text_params)
      render json: { success: true, selected_text: @selected_text }
    else
      render json: { success: false, errors: @selected_text.errors }
    end
  end
  
  def destroy
    @selected_text.destroy
    render json: { success: true }
  end
  
  private
  
  def set_selected_text
    @selected_text = SelectedText.find(params[:id])
  end
  
  def set_document
    @document = Document.find(params[:document_id])
  end
  
  def selected_text_params
    params.require(:selected_text).permit(:text, :text_type, :start_position, :end_position)
  end
end

# app/controllers/definitions_controller.rb
class DefinitionsController < ApplicationController
  before_action :set_definition, only: [:show, :edit, :update, :destroy]
  before_action :set_selected_text
  
  def create
    @definition = @selected_text.definitions.build(definition_params)
    
    if @definition.save
      render json: { success: true, definition: @definition }
    else
      render json: { success: false, errors: @definition.errors }
    end
  end
  
  def update
    if @definition.update(definition_params)
      render json: { success: true, definition: @definition }
    else
      render json: { success: false, errors: @definition.errors }
    end
  end
  
  def destroy
    @definition.destroy
    render json: { success: true }
  end
  
  private
  
  def set_definition
    @definition = Definition.find(params[:id])
  end
  
  def set_selected_text
    @selected_text = SelectedText.find(params[:selected_text_id])
  end
  
  def definition_params
    params.require(:definition).permit(:content, :context)
  end
end

# Similar controllers for Links, Notes, and Synonyms would follow the same pattern...

# ====================
# MIGRATIONS
# ====================

# db/migrate/001_create_documents.rb
class CreateDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.string :content_type, null: false
      t.string :file_path
      t.string :url
      t.text :content
      t.integer :total_pages
      t.integer :current_page, default: 1
      
      t.timestamps
    end
    
    add_index :documents, :title
    add_index :documents, :content_type
  end
end

# db/migrate/002_create_document_outlines.rb
class CreateDocumentOutlines < ActiveRecord::Migration[7.0]
  def change
    create_table :document_outlines do |t|
      t.references :document, null: false, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :document_outlines }
      t.string :title, null: false
      t.integer :level, null: false
      t.integer :position, default: 0
      t.integer :page_number
      t.string :anchor_id
      
      t.timestamps
    end
    
    add_index :document_outlines, [:document_id, :level]
    add_index :document_outlines, [:parent_id, :position]
  end
end

# db/migrate/003_create_selected_texts.rb
class CreateSelectedTexts < ActiveRecord::Migration[7.0]
  def change
    create_table :selected_texts do |t|
      t.references :document, null: false, foreign_key: true
      t.text :text, null: false
      t.string :text_type, default: 'general'
      t.integer :start_position
      t.integer :end_position
      
      t.timestamps
    end
    
    add_index :selected_texts, :text, unique: true
    add_index :selected_texts, :text_type
  end
end

# db/migrate/004_create_definitions.rb
class CreateDefinitions < ActiveRecord::Migration[7.0]
  def change
    create_table :definitions do |t|
      t.references :selected_text, null: false, foreign_key: true
      t.text :content, null: false
      t.text :context
      
      t.timestamps
    end
  end
end

# db/migrate/005_create_links.rb
class CreateLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :links do |t|
      t.references :selected_text, null: false, foreign_key: true
      t.string :url, null: false
      t.string :title, null: false
      t.text :description
      
      t.timestamps
    end
  end
end

# db/migrate/006_create_notes.rb
class CreateNotes < ActiveRecord::Migration[7.0]
  def change
    create_table :notes do |t|
      t.references :selected_text, null: false, foreign_key: true
      t.text :content, null: false
      t.datetime :added_at, default: -> { 'CURRENT_TIMESTAMP' }
      
      t.timestamps
    end
  end
end

# db/migrate/007_create_synonyms.rb
class CreateSynonyms < ActiveRecord::Migration[7.0]
  def change
    create_table :synonyms do |t|
      t.references :selected_text, null: false, foreign_key: true
      t.string :synonym_text, null: false
      
      t.timestamps
    end
    
    add_index :synonyms, :synonym_text
  end
end

# db/migrate/008_create_document_locations.rb
class CreateDocumentLocations < ActiveRecord::Migration[7.0]
  def change
    create_table :document_locations do |t|
      t.references :document, null: false, foreign_key: true
      t.references :selected_text, null: false, foreign_key: true
      t.integer :start_position, null: false
      t.integer :end_position, null: false
      t.integer :page_number
      
      t.timestamps
    end
    
    add_index :document_locations, [:document_id, :start_position]
  end
end

# ====================
# ROUTES
# ====================

# config/routes.rb
Rails.application.routes.draw do
  root 'documents#index'
  
  resources :documents do
    resources :selected_texts, only: [:create, :show, :update, :destroy] do
      resources :definitions, only: [:create, :update, :destroy]
      resources :links, only: [:create, :update, :destroy]
      resources :notes, only: [:create, :update, :destroy]
      resources :synonyms, only: [:create, :update, :destroy]
    end
  end
  
  # API routes for AJAX operations
  namespace :api do
    namespace :v1 do
      resources :documents, only: [:show] do
        member do
          get :outline
          get :highlight_text
        end
      end
      resources :selected_texts, only: [:show, :create, :update, :destroy]
    end
  end
end

# ====================
# VIEWS (Basic Structure)
# ====================

# app/views/layouts/application.html.erb
<!DOCTYPE html>
<html>
  <head>
    <title>Document Reader</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag 'application', 'data-turbo-track': 'reload' %>
    <%= javascript_pack_tag 'application', 'data-turbo-track': 'reload' %>
  </head>

  <body>
    <div class="app-container">
      <%= yield %>
    </div>
  </body>
</html>

# app/views/documents/show.html.erb
<div class="document-reader">
  <div class="left-pane">
    <div class="outline-section">
      <h3>Table of Contents</h3>
      <div id="document-outline">
        <!-- Outline tree will be populated here -->
      </div>
    </div>
    
    <div class="definitions-section">
      <h3>All Definitions</h3>
      <div id="definitions-list">
        <!-- Master definitions list will be populated here -->
      </div>
    </div>
  </div>
  
  <div class="center-pane">
    <div class="document-controls">
      <button id="prev-page">← Previous</button>
      <span id="page-info">Page <%= @document.current_page %> of <%= @document.total_pages %></span>
      <button id="next-page">Next →</button>
      <div class="zoom-controls">
        <button id="zoom-out">-</button>
        <span id="zoom-level">100%</span>
        <button id="zoom-in">+</button>
      </div>
    </div>
    
    <div class="document-content" id="document-content">
      <!-- Document content will be loaded here -->
    </div>
  </div>
  
  <div class="right-pane">
    <div class="selection-details" id="selection-details">
      <h3>Selection Details</h3>
      <div id="no-selection">Select text to view details</div>
      
      <div id="selected-text-info" style="display: none;">
        <div class="text-info">
          <h4>Selected Text</h4>
          <p id="selected-text-display"></p>
          <p><strong>Type:</strong> <span id="text-type"></span></p>
          <p><strong>Location:</strong> <span id="text-location"></span></p>
        </div>
        
        <div class="definitions-section">
          <h4>Definitions</h4>
          <div id="definitions-container"></div>
          <button id="add-definition">+ Add Definition</button>
        </div>
        
        <div class="links-section">
          <h4>Links</h4>
          <div id="links-container"></div>
          <button id="add-link">+ Add Link</button>
        </div>
        
        <div class="notes-section">
          <h4>Notes</h4>
          <div id="notes-container"></div>
          <button id="add-note">+ Add Note</button>
        </div>
        
        <div class="synonyms-section">
          <h4>Synonyms</h4>
          <div id="synonyms-container"></div>
          <button id="add-synonym">+ Add Synonym</button>
        </div>
      </div>
    </div>
  </div>
</div>

<%= javascript_pack_tag 'document_reader' %>

# ====================
# JAVASCRIPT (Stimulus Controllers)
# ====================

# app/javascript/controllers/document_reader_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "outline", "selectionDetails"]
  
  connect() {
    this.setupTextSelection()
    this.loadDocumentContent()
    this.loadOutline()
  }
  
  setupTextSelection() {
    // TODO: Implement text selection handling
  }
  
  loadDocumentContent() {
    // TODO: Load and display document content
  }
  
  loadOutline() {
    // TODO: Load and display document outline
  }
  
  handleTextSelection(event) {
    // TODO: Handle text selection events
  }
  
  addDefinition() {
    // TODO: Add definition for selected text
  }
  
  addLink() {
    // TODO: Add link for selected text
  }
  
  addNote() {
    // TODO: Add note for selected text
  }
  
  addSynonym() {
    // TODO: Add synonym for selected text
  }
}

# ====================
# CSS (Basic Structure)
# ====================

# app/assets/stylesheets/application.css
.document-reader {
  display: flex;
    height: 100vh;
      font-family: Arial, sans-serif;
      }

      .left-pane {
        width: 250px;
          background-color: #f5f5f5;
            border-right: 1px solid #ddd;
              overflow-y: auto;
                padding: 10px;
                }

                .center-pane {
                  flex: 1;
                    display: flex;
                      flex-direction: column;
                        background-color: white;
                        }

                        .right-pane {
                          width: 300px;
                            background-color: #f9f9f9;
                              border-left: 1px solid #ddd;
                                padding: 10px;
                                  overflow-y: auto;
                                  }

                                  .document-controls {
                                    display: flex;
                                      justify-content: space-between;
                                        align-items: center;
                                          padding: 10px;
                                            border-bottom: 1px solid #ddd;
                                              background-color: #f8f8f8;
                                              }

                                              .document-content {
                                                flex: 1;
                                                  padding: 20px;
                                                    overflow-y: auto;
                                                      user-select: text;
                                                      }

                                                      .zoom-controls {
                                                        display: flex;
                                                          align-items: center;
                                                            gap: 10px;
                                                            }

                                                            .outline-section, .definitions-section {
                                                              margin-bottom: 20px;
                                                              }

                                                              .outline-section h3, .definitions-section h3 {
                                                                margin: 0 0 10px 0;
                                                                  font-size: 14px;
                                                                    color: #333;
                                                                    }

                                                                    .selection-details h3 {
                                                                      margin: 0 0 15px 0;
                                                                        font-size: 16px;
                                                                          color: #333;
                                                                          }

                                                                          .text-info, .definitions-section, .links-section, .notes-section, .synonyms-section {
                                                                            margin-bottom: 20px;
                                                                              padding: 10px;
                                                                                background-color: white;
                                                                                  border-radius: 4px;
                                                                                    border: 1px solid #eee;
                                                                                    }

                                                                                    button {
                                                                                      padding: 8px 12px;
                                                                                        background-color: #007bff;
                                                                                          color: white;
                                                                                            border: none;
                                                                                              border-radius: 4px;
                                                                                                cursor: pointer;
                                                                                                  font-size: 12px;
                                                                                                  }

                                                                                                  button:hover {
                                                                                                    background-color: #0056b3;
                                                                                                    }

                                                                                                    .highlighted-text {
                                                                                                      background-color: #ffff99;
                                                                                                        cursor: pointer;
                                                                                                        }

                                                                                                        .selected-text {
                                                                                                          background-color: #87ceeb;
                                                                                                          }
                                                                                                          