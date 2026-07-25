class TaskNotifierJob < ApplicationJob
  queue_as :default

  def perform(task_id)
    task = Task.find(task_id)
    Rails.logger.info("[TaskNotifierJob] processed task #{task.id}: #{task.title.inspect}")
  end
end
