module ValidationErrorReporter
  class ModelResolver
    class << self
      def resolve(models = nil)
        return ActiveRecord::Base.descendants if models.nil?

        models.collect do |class_name|
          class_name.to_s.classify.constantize
        end
      end
    end
  end
end
