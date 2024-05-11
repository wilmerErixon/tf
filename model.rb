require 'sqlite3'

module Model
    extend self

    # Establishes a connection to the SQLite database
    #
    # @return [SQLite3::Database] A SQLite3 database connection object
    def connect_to_database
        db = SQLite3::Database.new('db/bookies.db')
        db.results_as_hash = true
        db
    end
    
    # Authenticates a user
    #
    # @param [String] username The username submitted in the form
    # @param [String] password The password submitted in the form
    #
    # @return [Hash]
    #   * :id [Integer] The ID of the user
    #   * :username [String] The username of the user
    #   * :authorization [String] The authorization level of the user
    #   * :error [String] The error message if authentication fails
    # @see Model#connect_to_database
    def authenticate_user(username, password)
        db = Model.connect_to_database
        result = db.execute("SELECT * FROM users WHERE username = ?", username).first
        if result.nil?
            return { error: "wrongUsername" }
        end
        pwdigest = result["pwdigest"]
        id = result["id"]
        if BCrypt::Password.new(pwdigest) == password
            authorization = (username == "ADMIN") ? "admin" : "user"
            return { id: id, username: username, authorization: authorization }
        else
            return { error: "wrongPassword" }
        end
    end

    # Checks if a username is already taken
    #
    # @param [String] username The username to check
    #
    # @return [Boolean] true if the username is already taken, false otherwise
    # @see Model#connect_to_database
    def username_taken?(username)
        db = Model.connect_to_database
        user = db.execute("SELECT 1 FROM users WHERE username = ?", username).first
        !user.nil?
    end
    
    # Creates a new user
    #
    # @param [String] username The username submitted in the form
    # @param [String] password_digest The hashed password
    # @see Model#connect_to_database
    def create_user(username, password_digest)
        db = Model.connect_to_database
        db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)', username, password_digest)
    end

    # Retrieves all books from the database
    #
    # @return [Array<Hash>] An array of hashes containing book data
    # @see Model#connect_to_database
    def get_all_books
        db = Model.connect_to_database
        db.execute("SELECT * FROM book")
    end

    # Retrieves book information by ID
    #
    # @param [Integer] book_id The ID of the book
    #
    # @return [Hash] A hash containing book information
    # @see Model#connect_to_database
    def get_book_info(book_id)
        db = Model.connect_to_database
        db.execute("SELECT id, title FROM book WHERE id = ?", book_id).first
    end

    # Retrieves title IDs associated with a user
    #
    # @param [Integer] user_id The ID of the user
    #
    # @return [Array<Integer>] An array of title IDs
    # @see Model#connect_to_database
    def get_user_title_ids(user_id)
        db = Model.connect_to_database
        db.execute("SELECT title_id FROM user_title_rel WHERE user_id = ?", user_id)
    end

    # Retrieves all genres from the database
    #
    # @return [Array<Hash>] An array of hashes containing genre data
    # @see Model#connect_to_database
    def get_all_genres
        db = Model.connect_to_database
        db.execute("SELECT * FROM genre")
    end

    # Creates a new book entry in the database
    #
    # @param [String] title The title of the book
    # @param [String] author The author of the book
    # @param [String] genre The genre of the book
    # @param [Integer] pages The number of pages in the book
    # @see Model#connect_to_database
    def newbook(title, author, genre, pages)
        db = Model.connect_to_database
        author_id = get_or_create_author_id(author)
        genre_id = db.execute("SELECT id FROM genre WHERE genre_name = ?", genre).first["id"]
        db.execute("INSERT INTO book (title, author_id, pages, genre_id) VALUES (?,?,?,?)", title, author_id, pages, genre_id)
    end

    # Retrieves detailed information about a book
    #
    # @param [Integer] id The ID of the book
    #
    # @return [Array] An array containing book, author, and genre information
    # @see Model#connect_to_database
    def get_book_details(id)
        db = Model.connect_to_database
        book = db.execute("SELECT * FROM book WHERE id = ?", id).first
        author = db.execute("SELECT author_name FROM author WHERE id IN (SELECT author_id FROM book WHERE id = ?)", id).first
        genre = db.execute("SELECT genre_name FROM genre WHERE id IN (SELECT genre_id FROM book WHERE id = ?)", id).first
        [book, author, genre]
    end

    # Deletes a book entry from the database
    #
    # @param [Integer] book_id The ID of the book to delete
    # @see Model#connect_to_database
    def delete_book(book_id)
        db = Model.connect_to_database
        db.execute("DELETE FROM book WHERE id = ?", book_id)
        db.execute("DELETE FROM user_title_rel WHERE title_id = ?", book_id)
    end

    # Adds a book to a user's collection
    #
    # @param [Integer] user_id The ID of the user
    # @param [Integer] title_id The ID of the book
    # @see Model#connect_to_database
    def add_book_to_collection(user_id, title_id)
        db = Model.connect_to_database
        current_ids = db.execute("SELECT title_id FROM user_title_rel WHERE user_id = ?", user_id)
        unless current_ids.any? { |id| id["title_id"] == title_id.to_i }
          db.execute("INSERT INTO user_title_rel (user_id, title_id) VALUES (?, ?)", user_id, title_id)
        end
    end

    # Removes a book from a user's collection
    #
    # @param [Integer] user_id The ID of the user
    # @param [Integer] title_id The ID of the book
    # @see Model#connect_to_database
    def remove_book_from_collection(user_id, title_id)
        db = Model.connect_to_database
        db.execute("DELETE FROM user_title_rel WHERE user_id = ? AND title_id = ?", user_id, title_id)
    end

    # Retrieves the name of a genre by its ID
    #
    # @param [Integer] genre_id The ID of the genre
    #
    # @return [String] The name of the genre
    # @see Model#connect_to_database
    def get_genre_name(genre_id)
        db = Model.connect_to_database
        genre = db.execute("SELECT genre_name FROM genre WHERE id = ?", genre_id).first
        genre ? genre["genre_name"] : nil
    end
    
    # Retrieves the name of an author by their ID
    #
    # @param [Integer] author_id The ID of the author
    #
    # @return [String] The name of the author
    # @see Model#connect_to_database
    def get_author_name(author_id)
        db = Model.connect_to_database
        author = db.execute("SELECT author_name FROM author WHERE id = ?", author_id).first
        author ? author["author_name"] : nil
    end

    # Updates book information in the database
    #
    # @param [Integer] book_id The ID of the book to update
    # @param [Hash] book_info The updated book information
    # @see Model#connect_to_database
    def update_book(book_id, book_info)
        db = Model.connect_to_database
        db.execute("UPDATE book SET title = ?, author_id = ?, genre_id = ?, pages = ? WHERE id = ?", book_info['title'], book_info['author_id'], book_info['genre_id'], book_info['pages'], book_id)
    end

    # Retrieves the ID of an existing author or creates a new one if not found
    #
    # @param [String] author The name of the author
    #
    # @return [Integer] The ID of the author
    # @see Model#connect_to_database
    def get_or_create_author_id(author)
        db = Model.connect_to_database
        author_id = db.execute("SELECT id FROM author WHERE author_name = ?", author).first
        if author_id.nil?
        db.execute("INSERT INTO author (author_name) VALUES (?)", author)
        author_id = db.last_insert_row_id
        else
        author_id = author_id["id"]
        end
        author_id
    end
end