require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"
require_relative "contacts_db_persistence"

configure do
  enable :sessions
  set :erb, :escape_html => true
  set :session_secret, SecureRandom.hex(32)
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "contacts_db_persistence.rb"
end

before do
  @storage = DB_Persistence.new(logger)
end

after do
  @storage.disconnect
end

helpers do
  def group_empty?(id)
    @storage.group_contacts_empty(id)
  end
end

def load_contact(id)
  contact = @storage.find_contact(id)
  return contact if contact
end

def error_for_contact_name(name)
  if !(1..100).cover? name.size
    "Name must be between 1 and 100 characters."
  elsif @storage.all_contacts.any? { |contact| contact[:name] == name }
    "You already have this person in your contacts"
  end
end

def error_for_adding_to_group(id, type)
  if @storage.group_includes?(id, type)
    "Contact already in this group."
  end
end

get "/" do
  redirect "/home"
end

# View Home Page
get "/home" do
  @groups = @storage.groups
  @contacts = @storage.all_contacts

  erb :home, layout: :layout
end

# Search bar
get "/search" do
  @query = params[:query]
  @results = @storage.contact_match(@query)
  
  erb :search, layout: :layout
end

# Render the new contact form
get "/new" do
  erb :new, layout: :layout
end

# Add new contact
post "/home" do
  name = params[:contact_name].strip
  phone = params[:contact_phone].strip
  email = params[:contact_email].strip

  error = error_for_contact_name(name)
  if error
    session[:error] = error
    erb :new
  else
    @storage.create_new_contact(name, phone, email)
    session[:success] = "Contact added!"
    redirect "/home"
  end
end

# View a single contact
get "/home/:id" do
  @contact_id = params[:id].to_i
  @contact = load_contact(@contact_id)

  erb :contact_page, layout: :layout
end

# Render group page
get "/home/group/:id" do
  @group_id = params[:id].to_i
  @group = @storage.get_group_type(@group_id)
  @group_contacts = @storage.retrieve_group_contacts(@group_id)
  @contacts = @storage.all_contacts

  erb :group, layout: :layout
end

# Render contact edit page
get "/home/:id/edit" do
  @contact_id = params[:id].to_i
  @contact = load_contact(@contact_id)

  erb :edit_contact, layout: :layout
end

# Edit contact info
post "/home/:id" do
  name = params[:contact_name].strip
  phone = params[:contact_phone].strip
  email = params[:contact_email].strip
  id = params[:id].to_i

  @storage.update_contact(name, phone, email, id)
  session[:success] = "This contact has been updated."
  redirect "/home/#{id}"
end

# Delete contact
post "/home/:id/delete" do
  id = params[:id].to_i

  @storage.delete_contact(id)

  session[:success] = "The contact has been deleted."
  redirect "/home"
end

# Render list of groups to add contact to
get "/home/:id/add_to_group" do
  @contact_id = params[:id].to_i
  @contact = load_contact(@contact_id)
  @groups = @storage.groups

  erb :add_to_group, layout: :layout
end

# Add contact to group
post "/home/groups/add/:id" do
  id = params[:id].to_i
  type = params[:group_name]
  group_id = @storage.get_group_id(type)


  error = error_for_adding_to_group(id, group_id)
  if error
    session[:error] = error
  else
    @storage.add_to_group(id, type)
    session[:success] = "Added!"
  end
  redirect "/home/group/#{group_id}"
end

# Remove contact from group
post "/home/group/:group_id/remove/:id" do
  id = params[:id].to_i
  group_id = params[:group_id].to_i

  @storage.remove_from_group(id, group_id)
  session[:success] = "Removed!"
  redirect "/home/group/#{group_id}"
end
