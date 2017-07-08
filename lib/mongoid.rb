# remove $oid from json string
module BSON
  class ObjectId
    alias :to_json :to_s
    alias :as_json :to_s
  end
end

# hot-fix to cancancan mongoid_adapter
module Mongoid::Matchable
  alias_method :matches?, :_matches?
end
