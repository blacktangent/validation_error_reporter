require "thread"

module ValidationErrorReporter
  class Runner

    class Entity

      def self.from_models(model_names)
        if model_names.nil?
          ActiveRecord::Base.descendants
        else
          model_names.collect do |model_name|
            model_name.classify.constantize
          end
        end.reject do |model|
          model.abstract_class? || !model.table_exists? ||  model.name.include?("HABTM_") || !model.public_methods.include?(:all)
        end
      end

    end

    def run(options = {})
      Rails.application.eager_load!

      @source_models = Entity.from_models(options[:models])

      formatted_text = format(get_errors(@source_models))

      if options[:print] == true
        puts formatted_text
      else
        Mail.deliver do
          to options[:email_to]
          from options[:email_from]
          subject "ShowModelError: Report"
          body formatted_text
        end
      end
    end

    private

    def get_errors(models)
      errors = []
      queue = Queue.new
      models.each {|model| queue.push(model) }
      workers = (0...ActiveRecord::Base.connection.pool.size).map do
        Thread.new do
          begin
            while model = queue.pop(true)
              ActiveRecord::Base.connection_pool.with_connection do |conn|
                model.all.find_each do |row|
                  unless row.valid?
                    errors << [model.model_name.human, row.public_send(model.primary_key), row.errors.full_messages]
                  end
                end
              end
            end
          rescue ThreadError => e
            puts e.message
          end
        end
      end
      workers.map(&:join)
      errors
    end

    def format(errors)
      PlaintextFormatter.format(errors)
    end
  end
end
