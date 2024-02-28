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

get('/bookies')  do
  id = session[:id].to_i
  db = SQLite3::Database.new('db/bookies.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM users WHERE id = ?",id)
  p "Alla bookies från result #{result}"
  slim(:"bookies/index",locals:{bookies:result})
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