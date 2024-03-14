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

get('/')  do
    slim(:start)
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
  slim(:wrongpassword)
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
    p session[:id]
    p session[:authorization]
    redirect('/bookies')
  else
    redirect('/wrongpassword')
  end
end

get('/logout') do
  session.clear
  redirect('/')
end

get('/bookies') do
  p session[:authorization]
  db = SQLite3::Database.new("db/bookies.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM book")
  slim(:"bookies/index")
end

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  if password == password_confirm
    password_digest = BCrypt::Password.create(password)
    db = SQLite3::Database.new('db/bookies.db')
    db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)',username,password_digest)
    redirect('/')
  else
    "Lösenorden matchade inte"
  end
end

get('/bookies/new') do
  db = SQLite3::Database.new("db/bookies.db")
  db.results_as_hash = true
  @genres = db.execute("SELECT * FROM genre")
  p @genres
  slim(:"bookies/new")
end

post('/bookies/new') do
  title = params[:title]
  author = params[:author]
  db = SQLite3::Database.new("db/bookies.db")
  db.results_as_hash = true
  p db.execute("SELECT id FROM author WHERE author_name = ?", author)
  if db.execute("SELECT id FROM author WHERE author_name = ?", author) == []
    db.execute("INSERT INTO author (author_name) VALUES (?)", (author))
  end
  pages = params[:pages]
  author_id = db.execute("SELECT id FROM author WHERE author_name = ?", author).first["id"]
  db.execute("INSERT INTO book (title, author_id, pages) VALUES (?,?,?)", title, author_id, pages)
  redirect('/bookies')
end 

get('/books/:id') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/bookies.db")
  db.results_as_hash = true
  result = db.execute("SELECT * FROM book WHERE id = ?",id).first
  result2 = db.execute("SELECT author_name FROM author WHERE id IN (SELECT author_id FROM book WHERE id = ?)", id).first
  p "Resultatet är: #{result2}" 
  slim(:"bookies/books",locals:{result:result,result2:result2})
end 