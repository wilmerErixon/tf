require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

get('/')  do
    slim(:start)
end 

get('/register')  do
  slim(:register)
end 

get('/showlogin')  do
  slim(:login)
end 

post('/login') do
  username = params[:username]
  password = params[:password]
  db = SQLite3::Database.new('db/todo2021.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM users WHERE username = ?",username).first
  pwdigest = result["pwdigest"]
  id = result["id"]
  
  if BCrypt::Password.new(pwdigest) == password
    session[:id] = id
    redirect('/bookies')
  else
    "Wrong password"
  end
end

get('/bookies')  do
  id = session[:id].to_i
  db = SQLite3::Database.new('db/todo2021.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM todos WHERE user_id = ?",id)
  p "Alla todos från result #{result}"
  slim(:"bookies/index",locals:{bookies:result})
end 

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  if password == password_confirm
    password_digest = BCrypt::Password.create(password)
    db = SQLite3::Database.new('db/todo2021.db')
    db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)',username,password_digest)
    redirect('/')
  else
    "Lösenorden matchade inte"
  end
end