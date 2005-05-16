#!/usr/local/bin/ruby -w

# $Id$

# the interpreter
#
# this builds our virtual pinball machine, into which we'll place our host-specific
# information and out of which we'll receive our host-specific configuration

require 'blink'


module Blink
    #------------------------------------------------------------
    class TransObject < Hash
        attr_accessor :type

        @@ohash = {}
        @@oarray = []

        def TransObject.clear
            @@oarray.clear
        end

        def TransObject.list
            return @@oarray
        end

        def initialize(name,type)
            self[:name] = name
            @type = type
            #if @@ohash.include?(name)
            #    raise "%s already exists" % name
            #else
            #    @@ohash[name] = self
            #    @@oarray.push(self)
            #end
            @@oarray.push self
        end

        def name
            return self[:name]
        end

        def to_s
            return "%s(%s) => %s" % [@type,self[:name],super]
        end

        def to_type
            retobj = nil
            if type = Blink::Type.type(self.type)
                namevar = type.namevar
                if namevar != :name
                    self[namevar] = self[:name]
                    self.delete(:name)
                end
                begin
                    # this will fail if the type already exists
                    # which may or may not be a good thing...
                    retobj = type.new(self)
                rescue => detail
                    Blink.error "Failed to create object: %s" % detail 
                    #puts object.class
                    #puts object.inspect
                    #exit
                end
            else
                raise "Could not find object type %s" % self.type
            end

            return retobj
        end
    end
    #------------------------------------------------------------

    #------------------------------------------------------------
    class TransSetting
        attr_accessor :type, :name, :args, :evalcount

        def initialize
            @evalcount = 0
        end

        def evaluate
            @evalcount += 0
            if type = Blink::Type.type(self.type)
                # call the settings
                if type.allowedmethod(self.name)
                    type.send(self.name,self.args)
                else
                    Blink.error("%s does not respond to %s" % [self.type,self.name])
                end
            else
                raise "Could not find object type %s" % setting.type
            end
        end
    end
    #------------------------------------------------------------

    #------------------------------------------------------------
    # just a linear container for objects
    class TransBucket < Array
        def to_type
            # this container will contain the equivalent of all objects at
            # this level
            container = Blink::Component.new
            nametable = {}

            self.each { |child|
                # the fact that we descend here means that we are
                # always going to execute depth-first
                # which is _probably_ a good thing, but one never knows...
                if child.is_a?(Blink::TransBucket)
                    # just perform the same operation on any children
                    container.push(child.to_type)
                elsif child.is_a?(Blink::TransSetting)
                    # XXX this is wrong, but for now just evaluate the settings
                    child.evaluate
                elsif child.is_a?(Blink::TransObject)
                    # do a simple little naming hack to see if the object already
                    # exists in our scope
                    # this assumes that type/name combinations are globally
                    # unique
                    name = [child[:name],child[:type]].join("--")

                    if nametable.include?(name)
                        object = nametable[name]
                        child.each { |var,value|
                            # don't rename; this shouldn't be possible anyway
                            next if var == :name

                            # override any existing values
                            object[var] = value
                        }
                    else # the object does not exist yet in our scope
                        # now we have the object instantiated, in our scope
                        object = child.to_type
                        nametable[name] = object

                        # this sets the order of the object
                        container.push object
                    end
                else
                    raise "TransBucket#to_type cannot handle objects of type %s" %
                        child.class
                end
            }

            # at this point, no objects at are level are still Transportable
            # objects
            return container
        end

    end
    #------------------------------------------------------------
end
