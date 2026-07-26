class LoadBalancerController < ApplicationController
  # Diagnostic JSON endpoint, not a browser form -- no session-based CSRF token to send.
  skip_before_action :verify_authenticity_token

  rescue_from LoadBalancer::UnknownStrategyError, with: :render_unknown_strategy
  rescue_from LoadBalancer::NoHealthyBackendsError, with: :render_no_healthy_backends
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  # GET /backends
  def index
    render json: Backend.all.as_json(only: %i[id host weight healthy active_connections times_selected])
  end

  # POST /route
  def create
    backend = LoadBalancer.new(strategy: strategy_param).route
    render json: backend_json(backend), status: :created
  end

  # DELETE /route
  def destroy
    backend = Backend.find_by!(host: params.require(:host))
    backend.release!
    render json: backend_json(backend)
  end

  private
    def strategy_param
      params[:strategy].presence || :round_robin
    end

    def backend_json(backend)
      backend.as_json(only: %i[id host weight healthy active_connections times_selected])
    end

    def render_unknown_strategy(error)
      render json: { error: error.message }, status: :unprocessable_content
    end

    def render_no_healthy_backends(error)
      render json: { error: error.message }, status: :service_unavailable
    end

    def render_not_found(error)
      render json: { error: error.message }, status: :not_found
    end
end
