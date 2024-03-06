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
  slim(:"bookies/new")
end

post('/bookies/new') do
  name = params[:name]
  author_id = params[:author_id].to_i
  p "Vi fick in data #{name} och #{author_id}"
  db = SQLite3::Database.new("db/bookies.db")
  db.execute("INSERT INTO albums (name, author_id) VALUES (?,?)", title, author_id)
  redirect('/bookies')
end 