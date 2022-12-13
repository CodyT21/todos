require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  
  set :erb, :escape_html => true
end

helpers do
  def all_todos_completed?(list)
    list[:todos].all? { |todo| todo[:completed] }
  end

  def list_completed?(list)
    all_todos_completed?(list) && !new_list?(list)
  end

  def new_list?(list)
    list[:todos].empty?
  end

  def list_class(list)
    list_completed?(list) ? 'complete' : nil
  end

  def remaining_todos(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todo_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list) }

    incomplete_lists.each { |list| block.call(list, lists.index(list)) }
    complete_lists.each { |list| block.call(list, lists.index(list)) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| block.call(todo, todos.index(todo)) }
    complete_todos.each { |todo| block.call(todo, todos.index(todo)) }
  end
end

def load_list(list_id)
  list = session[:lists][list_id] if list_id && session[:lists][list_id]
  return list if list
  
  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

# Returns an error message for invalid list names
def list_error_message(list_name)
  if session[:lists].any? { |list| list[:name] == list_name }
    'That list name already exists.'
  elsif !(1..100).include? list_name.size
    'List name must be between 1 and 100 characters.'
  end
end

# Returns an error message for invalid todo list items
def todo_error_message(todo)
  return 'Todo item must be between 1 and 100 characters.' unless (1..100).include? todo.size
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View all the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = list_error_message(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Render the todo list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  erb :todo_list, layout: :layout
end

# Edit name of todo list
post '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  list_name = params[:list_name].strip
  error = list_error_message(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list name has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Add todo to todo list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo = params[:todo].strip
  error = todo_error_message(todo)

  if error
    session[:error] = error
    erb :todo_list, layout: :layout
  else
    session[:lists][@list_id][:todos] << { name: todo, completed: false }
    session[:success] = 'This todo item has been added.'
    redirect "/lists/#{@list_id}"
  end
end

# Render the todo list edit page
get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  erb :edit_list, layout: :layout
end

# Remove todo list from lists
post '/lists/:list_id/destroy' do
  list_id = params[:list_id].to_i
  session[:lists].delete_at list_id
  session[:success] = 'The list has been deleted.'

  redirect '/lists'
end

# Remove todo list from lists
post '/lists/:list_id/todos/:todo_id/destroy' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  list = load_list(list_id)
  list[:todos].delete_at todo_id
  session[:success] = 'The todo has been deleted.'

  redirect "/lists/#{list_id}"
end

# Update status of a todo list item
post '/lists/:list_id/todos/:todo_id' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  status = params[:completed] == 'true'
  list = load_list(list_id)
  list[:todos][todo_id][:completed] = status

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{list_id}"
end

# Complete all todo list items
post '/lists/:list_id/complete_all' do
  list_id = params[:list_id].to_i
  list = load_list(list_id)
  list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = 'All todo list items have been marked as complete.'
  redirect "/lists/#{list_id}"
end
