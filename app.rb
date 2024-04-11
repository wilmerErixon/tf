require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

helpers do
  def logged_in?
    !session[:id].nil? && !session[:username].nil?
  end
end

total_attempts = 3
first_cooldown = 2
ultimateCooldown = 500

before '/login' do
  session[:attempts] ||=0
  if session[:attempts] >= total_attempts
    cooldown = [first_cooldown * (2 ** (session[:attempts] - total_attempts)), ultimateCooldown].min
    if Time.now - (session[:latestAttempt] || Time.now) < cooldown 
      halt 429, "Too many attempts! Please wait #{cooldown - (Time.now - session[:latestAttempt]).to_i} seconds."
    end
  end
end

get('/')  do
  redirect('/bookies')
end 

get('/register')  do
  slim(:register)
end 

get('/showlogin')  do
  slim(:login)
end 

get('/wrongusername') do
  slim(:wrongUsername)
end

get('/wrongpassword') do
  slim(:wrongPassword)
end

get('/notAuthorized') do
  slim(:"notAuthorized")
end

get('/notLoggedIn') do
  slim(:"notLoggedIn")
end

get('/usedUser') do
  slim(:"usedUser")
end

get('/emptyError') do
  slim(:"emptyError")
end

post('/login') do
  username = params[:username]
  password = params[:password]
  db = SQLite3::Database.new('db/bookies.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM users WHERE username = ?",username).first
  if result == nil 
    redirect('/wrongusername')
  end
  pwdigest = result["pwdigest"]
  id = result["id"]

  if BCrypt::Password.new(pwdigest) == password
    session[:id] = id
    session[:username] = username
    if username == "ADMIN"
      session[:authorization] = "admin"
    else 
      session[:authorization] = "user"
    end
    redirect('/bookies')
  else
    session[:latestAttempt] = Time.now
    session[:attempts] += 1
    redirect('/wrongpassword')
  end
end

get('/logout') do
  session.clear
  redirect('/')
end

get('/bookies') do
  
  db = SQLite3::Database.new("db/bookies.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM book")
  slim(:"bookies/index")
end

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  db = SQLite3::Database.new('db/bookies.db')
  db.results_as_hash = true
  userDatabase = db.execute("SELECT username FROM users")

  userDatabase.each do |name| 
    name = name["username"] 
    if name == username
      redirect('/usedUser')
    end
  end

  if username == "" || password == ""
    redirect('/emptyError')
  end

  if password == password_confirm
    password_digest = BCrypt::Password.create(password)
    db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)',username,password_digest)
    redirect('/')
  else
    "Lösenorden matchade inte"
  end
end

get('/myBooks') do
  if !logged_in?
    redirect('notLoggedIn')
  end
  @db = SQLite3::Database.new('db/bookies.db')
  @db.results_as_hash = true
  @title_ids = @db.execute("SELECT title_id FROM user_title_rel WHERE user_id = ?", session[:id])
  slim(:"/users/myBooks")
end

get('/bookies/new') do
  if session[:authorization] != "admin"
    redirect('/notAuthorized')
  end
  db = SQLite3::Database.new("db/bookies.db")
  db.results_as_hash = true
  @genres = db.execute("SELECT * FROM genre")
  p @genres
  slim(:"bookies/new")
end

post('/bookies/new') do
  title = params[:title]
  author = params[:author]
  genre = params[:genre]
  db = SQLite3::Database.new("db/bookies.db")
  db.results_as_hash = true
  p db.execute("SELECT id FROM author WHERE author_name = ?", author)
  if db.execute("SELECT id FROM author WHERE author_name = ?", author) == []
    db.execute("INSERT INTO author (author_name) VALUES (?)", (author))
  end
  pages = params[:pages]
  author_id = db.execute("SELECT id FROM author WHERE author_name = ?", author).first["id"]
  genre_id = db.execute("SELECT id FROM genre WHERE genre_name = ?", genre).first["id"]
  db.execute("INSERT INTO book (title, author_id, pages, genre_id) VALUES (?,?,?,?)", title, author_id, pages, genre_id)
  redirect('/bookies')
end 

get('/books/:id') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/bookies.db")
  db.results_as_hash = true
  book = db.execute("SELECT * FROM book WHERE id = ?",id).first
  author = db.execute("SELECT author_name FROM author WHERE id IN (SELECT author_id FROM book WHERE id = ?)", id).first
  genre = db.execute("SELECT genre_name FROM genre WHERE id IN (SELECT genre_id FROM book WHERE id = ?)", id).first
  p  "#{book}, #{author}, #{genre}" 
  slim(:"bookies/books",locals:{book:book,author:author,genre:genre})
end 

post('/books/:id/delete') do
  if session[:authorization] != "admin"
    redirect('/notAuthorized')
  end
  id = params[:id].to_i
  db = SQLite3::Database.new("db/bookies.db")
  db.execute("DELETE FROM book WHERE id = ?",id)
  db.execute("DELETE FROM user_title_rel WHERE title_id = ?", id)
  redirect('/bookies')
end

post('/books/:id/add') do
  title_id = params[:id]
  user_id = session[:id]
  db = SQLite3::Database.new('db/bookies.db')
  db.results_as_hash = true
  current_ids = db.execute("SELECT title_id FROM user_title_rel WHERE user_id = ?", user_id)
  current_ids.each do |id| 
    p id["title_id"] 
    p title_id
    if id["title_id"] == title_id.to_i
      redirect('/myBooks')
    end
  end
  db.execute("INSERT INTO user_title_rel (user_id, title_id) VALUES (?,?)", user_id, title_id)
  redirect('/myBooks')
end

delete('/books/:id/remove') do
  title_id = params[:id]
  user_id = session[:id]
  db = SQLite3::Database.new('db/bookies.db')
  db.results_as_hash = true
  db.execute("DELETE FROM user_title_rel WHERE user_id = ? AND title_id = ?", user_id, title_id)
  redirect '/myBooks'
end