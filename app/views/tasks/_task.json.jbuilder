json.extract! task, :id, :title, :done, :created_at, :updated_at
json.url task_url(task, format: :json)
