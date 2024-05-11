# Require necessary gems and local files
require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require_relative './model.rb'

# Enable sessions
enable :sessions

# Include Model module
include Model

# Helper methods for authentication
helpers do
  # Checks if a user is logged in
  def logged_in?
    !session[:id].nil? && !session[:username].nil?
  end

  # Checks if a user is authorized as an admin
  def authorized?
    session[:authorization] == "admin"
  end
end

# Constants for login attempt control
totalAttempts = 3
innitialCooldown = 2
ultimateCooldown = 500

# Before filter to control login attempts
before '/login' do
  session[:attempts] ||=0
  if session[:attempts] >= totalAttempts
    cooldown = [innitialCooldown * (2 ** (session[:attempts] - totalAttempts)), ultimateCooldown].min
    if Time.now - (session[:latestAttempt] || Time.now) < cooldown 
      halt 429, "Too many attempts! Please wait #{cooldown - (Time.now - session[:latestAttempt]).to_i} seconds."
    end
  end
end

# Display Landing Page
#
get('/') do
  slim(:index)
end 

# Displays the registration form
#
get('/register') do
  slim(:register)
end 

# Displays the login form
#
get('/showlogin') do
  slim(:login)
end 

# Displays the not authorized page
#
get('/notAuthorized') do
  slim(:notAuthorized)
end

# Handles login request
#
# @param [String] username, The username
# @param [String] password, The password
#
# @see Model#authenticate_user
post('/login') do
  username = params[:username]
  password = params[:password]
  authentication_result = Model.authenticate_user(username, password)

  if authentication_result[:error]
    session[:error] = authentication_result[:error]
    redirect('/showlogin')
  else
    session[:id] = authentication_result[:id]
    session[:username] = authentication_result[:username]
    session[:authorization] = authentication_result[:authorization]
    redirect('/bookies')
  end
end

# Handles logout request
#
get('/logout') do
  session.clear
  redirect('/')
end

# Renders the bookies page with all books
#
get('/bookies') do
  all_books = Model.get_all_books
  slim(:"bookies/index", locals: { all_books: all_books})
end

# Handles new user registration
#
# @param [String] username, The username
# @param [String] password, The password
# @param [String] password_confirm, The confirmation password
#
# @see Model#username_taken?
# @see Model#create_user
post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  if Model.username_taken?(username)
    session[:error] = "usedUser"
    redirect('/register')
  end
  if username.empty? || password.empty?
    session[:error] = "blankSpace"
    redirect('/register')
  end
  if password == password_confirm
    password_digest = BCrypt::Password.create(password)
    Model.create_user(username, password_digest)
    redirect('/')
  else
    session[:error] = "noMatch"
    redirect('/register')
  end
end

# Renders the user's books page
#
get('/myBooks') do
  redirect('/notAuthorized') unless logged_in?
  title_ids = Model.get_user_title_ids(session[:id])
  slim(:"/users/myBooks", locals: { title_ids: title_ids })
end

# Renders the form for adding a new book
#
get('/bookies/new') do
  redirect('/notAuthorized') unless authorized?
  genres = Model.get_all_genres
  slim(:"bookies/new", locals: { genres: genres })
end

# Handles adding a new book
#
# @param [String] title, The title of the book
# @param [String] author, The author of the book
# @param [String] genre, The genre of the book
# @param [Integer] pages, The number of pages of the book
#
# @see Model#newbook
post('/bookies/new') do
  title = params[:title]
  author = params[:author]
  genre = params[:genre]
  pages = params[:pages]
  Model.newbook(title, author, genre, pages)
  redirect('/bookies')
end 

# Renders details of a single book
#
# @param [Integer] id, The ID of the book
#
# @see Model#get_book_details
get('/books/:id') do
  id = params[:id].to_i
  book, author, genre = Model.get_book_details(id)
  slim(:"bookies/books", locals: { book: book, author: author, genre: genre })
end

# Handles deleting a book
#
# @param [Integer] id, The ID of the book
#
# @see Model#delete_book
post('/books/:id/delete') do
  redirect('/notAuthorized') unless authorized?
  book_id = params[:id].to_i
  Model.delete_book(book_id)
  redirect('/bookies')
end

# Handles adding a book to a user's collection
#
# @param [Integer] id, The ID of the book
#
# @see Model#add_book_to_collection
post('/books/:id/add') do
  title_id = params[:id]
  user_id = session[:id]
  Model.add_book_to_collection(user_id, title_id)
  redirect('/myBooks')
end

# Handles removing a book from a user's collection
#
# @param [Integer] id, The ID of the book
#
# @see Model#remove_book_from_collection
delete('/books/:id/remove') do
  title_id = params[:id]
  user_id = session[:id]
  Model.remove_book_from_collection(user_id, title_id)
  redirect '/myBooks'
end

# Renders the form for editing a book
#
# @param [Integer] id, The ID of the book
#
# @see Model#get_book_info
# @see Model#get_all_genres
# @see Model#get_genre_name
# @see Model#get_author_name
# @see Model#update_book
get('/books/:id/edit') do
  redirect('/notAuthorized') unless authorized?
  id = params[:id]
  book_info = Model.get_book_info(id)
  genres = Model.get_all_genres
  genre = Model.get_genre_name(book_info["genre_id"])
  author = Model.get_author_name(book_info["author_id"])
  title = book_info["title"]
  pages = book_info["pages"]
  slim(:edit, locals: { genres: genres, genre: genre, title: title, author: author, pages: pages})
end

# Handles updating book information
#
# @param [Integer] id, The ID of the book
# @param [String] author, The new author of the book
# @param [String] title, The new title of the book
# @param [String] genre, The new genre of the book
# @param [Integer] pages, The new number of pages of the book
#
# @see Model#get_or_create_author_id
# @see Model#update_book
post('/books/:id/edit') do
  id = params[:id]
  book_info = Model.get_book_info(id)
  genres = Model.get_all_genres
  unless params[:author].empty?
    author_id = Model.get_or_create_author_id(params[:author])
    book_info['author_id'] = author_id
  end
  book_info['title'] = params[:title] unless params[:title].empty?
  unless params[:genre].empty?
    genre_id = genres.find { |genre| genre['genre_name'] == params[:genre] }&.fetch('id', nil)
    book_info['genre_id'] = genre_id
  end
  book_info['pages'] = params[:pages] unless params[:pages].empty?
  Model.update_book(id, book_info)
  redirect('/bookies')
end
