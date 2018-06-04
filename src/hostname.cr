# Copyright (c) 2018 Christian Huxtable <chris@huxtable.ca>.
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require "socket"
require "ip_address"


class Hostname

	# MARK: - Initializer

	# :nodoc:
	protected def initialize(@parts : Array(String))
	end


	# MARK: - Factories

	# Constructs a new `Hostname` by interpreting the contents of a `String`.
	#
	# Expects an hostname like "example.com" or "example.com.".
	#
	# Raises: `MalformedError` when the input is malformed.
	def self.[](string : String) : self
		return new(string)
	end

	# ditto
	def self.new(string : String) : self
		return new?(string) || raise MalformedError.new()
	end

	# Constructs a new `Hostname` by interpreting the contents of a `String`.
	#
	# Expects an hostname like "example.com" or "example.com.".
	#
	# Returns: `nil` when the input is malformed.
	def self.[]?(string : String) : self?
		return new?(string)
	end

	# ditto
	def self.new?(string : String) : self?
		parts = Parser.parse(string)
		return nil if ( !parts )

		instance = self.allocate
		instance.initialize(parts)
		return instance
	end

	# Constructs a new `Hostname` by interpreting the contents of an `Array` of `String`s.
	#
	# Expects input like: ```["example", "com"]```.
	#
	# Raises: `MalformedError` when the input is malformed.
	def self.new(parts : Array(String)) : self
		return new?(parts) || raise MalformedError.new()
	end

	# Constructs a new `Hostname` by interpreting the contents of an `Array` of `String`s.
	#
	# Expects input like: ```["example", "com"]```.
	#
	# Returns: `nil` when the input is malformed.
	def self.new?(parts : Array(String))
		parts = Parser.validate(parts)
		return nil if ( !parts )

		instance = self.allocate
		instance.initialize(parts)
		return instance
	end


	# MARK: - Properties

	getter parts : Array(String)

	# Returns the number of characters in the whole hostname.
	def size() : UInt32
		return parts.reduce(-1) { |memo, part| memo + part.size + 1 }.to_u32
	end

	# Returns the number of levels in the hostname
	def levels() : UInt32
		return @parts.size().to_u32
	end


	# MARK: - Queries

	def [](index : Int) : String
		return @parts[index]
	end

	# Indicates if the domain is a top level domain.
	def tld?() : Bool
		return ( levels() == 1 )
	end


	# MARK: - Matching

	# Indicates if the domain has the given top level domain.
	def tld?(tld : String) : Bool
		return ( @parts.last == tld )
	end

	# Indicates if the domain has one of the given top level domains.
	def tld?(*tlds : String) : Bool
		return tld?(tlds)
	end

	# ditto
	def tld?(tlds : Enumerable(String)) : Bool
		return tlds.includes?(@parts.last)
	end

	# Indicates if the reciever is a subdomain of the given hostname.
	def subdomain?(other : Hostname, fqn : Bool = false) : Bool
		return false if (self.levels >= other.levels)

		o_iter = other.parts.reverse_each()
		s_iter = @parts.reverse_each()

		loop {
			o_entry = o_iter.next
			s_entry = s_iter.next

			return false if ( o_entry.is_a?(Iterator::Stop) )
			return true if ( s_entry.is_a?(Iterator::Stop) )
			return false if ( o_entry != s_entry )
		}
	end

	# Compares this hostname with another, returning `-1`, `0` or `+1` depending if the
	# hostname is less, equal or greater than the *other* hostname.
	#
	# This compares the top level alphabetically. If they match the next next level is tried.
	def <=>(other : Hostname) : Int
		o_iter = other.parts.reverse_each()
		s_iter = @parts.reverse_each()

		loop {
			o_entry = o_iter.next
			s_entry = s_iter.next

			return 0 if ( o_entry.is_a?(Iterator::Stop) && s_entry.is_a?(Iterator::Stop) )
			return 1 if ( o_entry.is_a?(Iterator::Stop) )
			return -1 if ( s_entry.is_a?(Iterator::Stop) )

			diff = (o_entry <=> s_entry)
			return diff if ( !diff.zero? )
		}
	end


	# MARK: - Relatives

	# Creates the parent hostname.
	#
	# Raises: `Enumerable::EmptyError` if the hostname is a Top-Level-Domain.
	def parent(depth : Int = 1) : Hostname
		raise Enumerable::EmptyError.new("No parent for Top-Level-Domain #{self.to_s.inspect}.") if ( tld? )
		return parent?(depth) || raise MalformedError.new()
	end

	# Creates the parent hostname.
	#
	# Returns: `nil` if the hostname is a Top-Level-Domain.
	def parent?(depth : Int = 1) : Hostname?
		return nil if ( tld? )
		return new?(@parts[1..-1])
	end

	# Creates a new child hostname (subdomain).
	#
	# Raises: `MalformedError` if the hostname is malformed.
	def child(name : String) : Hostname
		return parent?(depth) || raise MalformedError.new(name)
	end

	# Creates a new child hostname (subdomain).
	#
	# Returns: `nil` if the hostname is malformed.
	def child?(name : String) : Hostname?
		return nil if ( !NAME_REGEX.match?(name) )
		parts = Array(String).build(@parts.size + 1) { |buffer|
			buffer[0] = name
			(buffer + 1).copy_from(@parts.to_unsafe(), @parts.size)
		}
		return new?(parts)
	end


	# MARK: - Resolution

	# Returns the first `IP::Address` resolved for the hostname.
	#
	# Raises: `nil` if no address is found.
	def address(family = Socket::Family::INET, type = Socket::Type::STREAM, protocol = Protocol::IP, timeout = nil) : IP::Address
		return address?(family, type, protocol, timeout) || raise NotFoundError.new(self)
	end

	# Returns the first `IP::Address` resolved for the hostname.
	#
	# Returns: `nil` if no address is found.
	def address?(family = Socket::Family::INET, type = Socket::Type::STREAM, protocol = Protocol::IP, timeout = nil) : IP::Address?
		each_address(family, type, protocol, timeout) { |address|
			return address if ( !address.nil? )
		}
	end

	# Returns an `Array` of `IP::Address`es that were resolved for the hostname.
	def addresses(family = Socket::Family::INET, type = Socket::Type::STREAM, protocol = Protocol::IP, timeout = nil) : Array(IP::Address)
		addresses = Array(IPAddress).new()
		each_address(family, type, protocol, timeout) { |address|
			addresses << address if ( !address.nil? )
		}
		return addresses.uniq!
	end

	# Yields the `IP::Address`es that were resolved for the hostname.
	def each_address(family = Socket::Family::INET, type = Socket::Type::STREAM, protocol = Socket::Protocol::IP, timeout = nil, &block)
		getaddrinfo(self.to_s(), nil, family, type, protocol, timeout) { |addrinfo_ptr|
			yield IP::Address.new(addrinfo_ptr.value.ai_addr)
		}
	end

	# Yields the `IP::Address`es, `Socket::Type`s, and `Socket:: Protocol`s that were resolved for the hostname.
	def resolve(family = Socket::Family::INET, type = Socket::Type::STREAM, protocol = Socket::Protocol::IP, timeout = nil, &block)
		getaddrinfo(self.to_s(), nil, family, type, protocol, timeout) { |ptr|
			address = IP::Address.new(ptr.value.ai_addr)
			type = Socket::Type.new(ptr.value.ai_socktype)
			protocol = Socket::Type.new(ptr.value.ai_socktype)
			yield(address, type, protocol)
		}
	end

	# :nodoc:
	private def getaddrinfo(domain, service, family, type , protocol, timeout)
		hints = LibC::Addrinfo.new
		hints.ai_family = (family || Socket::Family::UNSPEC).to_i32
		hints.ai_socktype = type
		hints.ai_protocol = protocol
		hints.ai_flags = 0

		hints.ai_flags |= LibC::AI_NUMERICSERV if ( service.is_a?(Int) )

		# On OS X < 10.12, the libsystem implementation of getaddrinfo segfaults
		# if AI_NUMERICSERV is set, and servname is NULL or 0.
		{% if flag?(:darwin) %}
			if (service == 0 || service == nil) && (hints.ai_flags & LibC::AI_NUMERICSERV)
				hints.ai_flags |= LibC::AI_NUMERICSERV
				service = "00"
			end
		{% end %}

		ret = LibC.getaddrinfo(domain, service.to_s, pointerof(hints), out ptr)

		begin
			case ret
				when 0 # success
				when LibC::EAI_NONAME then raise ResolutionError.new("No address found for #{domain}:#{service} over #{protocol}")
				else raise ResolutionError.new("getaddrinfo: #{String.new(LibC.gai_strerror(ret))}")
			end

			yield ptr
		ensure
			LibC.freeaddrinfo(ptr)
		end
	end


	# MARK: - Stringification

	# Appends the string representation of this hostname to the given `IO`.
	def to_s(io : IO) : Nil
		return to_s(false, io)
	end

	# Appends the string representation of this hostname to the given `IO` with the option
	# of making the hostname fully qualified.
	def to_s(fqn : Bool, io : IO) : Nil
		@parts.join('.', io)
		io << '.' if ( fqn )
	end

	# Returns the string representation of this hostname with the option of making the
	# hostname fully qualified.
	def to_s(fqn : Bool) : String
		return String.build() { |io| self.to_s(fqn, io) }
	end


	# MARK: - Errors

	# :nodoc:
	class MalformedError < Exception
		def new(was : String)
			return new("The hostname was malformed: was #{was}")
		end

		def new()
			return new("The hostname was malformed.")
		end
	end

	# :nodoc:
	class Invalid < Exception; end

	# :nodoc:
	class NotFoundError < Exception
		def new(hostname : Hostname)
			return new("No address could be resolved for #{self.inspect}.")
		end
	end

	# :nodoc:
	class ResolutionError < Exception; end

	class Parser

		SEPARATOR = '.'
		@char : Char?

		def self.parse(string : String) : Array(String)?
			parser = new(string)
			return parser.parse()
		end

		def self.validate(parts : Array(String)) : Array(String)?
			parts = validate_sizes(parts)
			return nil if ( !parts )

			parts = validate_parts(parts)
			return nil if ( !parts )

			return parts
		end


		# MARK: - Initializer

		def initialize(string : String)
			@cursor = Char::Reader.new(string)
			@char = @cursor.current_char()
		end


		# MARK: - Utilities

		def self.validate_sizes(parts : Array(String)) : Array(String)?
			return nil if ( parts.empty?() )
			return nil if ( parts.size() > 127 )

			length = parts.reduce(0) { |memo, part| memo + part.size }
			length += (parts.size - 1)
			return nil if ( length < 1 || length > 253 )

			return parts
		end

		def self.validate_parts(parts : Array(String)) : Array(String)?
			parts.each() { |part|
				return nil if ( part.empty? )
				return nil if ( part.size > 63 )

				return nil if part[0].ascii_alphanumeric?
				return nil if part[-1].ascii_alphanumeric?

				part.each_char_with_index() { |char, index|
					return nil if ( !char.ascii_alphanumeric? && char != '-' && char != '_' )
				}
			}

			return parts
		end

		# Parse a whole hostname.
		protected def parse() : Array(String)?
			parts = Array(String).new()

			while ( part = parse_part() )
				parts << part
			end

			return nil if !at_end?()
			return Parser.validate_sizes(parts)
		end

		# Parse a part of the hostname.
		protected def parse_part() : String?
			return nil if at_end?()

			string = String.build() { |buffer|
				char = current?()

				return nil if ( !char )
				return nil if ( char == SEPARATOR )
				return nil if !char.ascii_alphanumeric?
				buffer << char.downcase

				while ( char = self.next?() )
					break if ( char == SEPARATOR )
					return nil if !char.ascii_alphanumeric? && char != '-' && char != '_'
					buffer << char.downcase
				end
				self.next?
			}
			return nil if ( string.size < 1 )
			return nil if ( string.size > 63 )

			return nil if !string[0].ascii_alphanumeric?
			return nil if !string[-1].ascii_alphanumeric?

			return string
		end

		# Is the cursor at the end?
		protected def at_end?() : Bool
			return !@cursor.has_next?
		end

		# What is the current character.
		protected def current?() Char?
			return @char
		end

		# Move to the next position, return the character or `nil`.
		protected def next?() : Char?
			return @char = nil if at_end?
			@char = @cursor.next_char()
			@char = nil if @char == Char::ZERO
			return @char
		end

	end

end
