class BannedWordsController < ApplicationController
  before_action :set_banned_word, only: %i[update destroy]

  def index
    render json: BannedWord.all
  end

  def create
    banned_word = BannedWord.new(banned_word_params)

    if banned_word.save
      render json: banned_word, status: :created
    else
      render json: { errors: banned_word.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    if @banned_word.update(banned_word_params)
      render json: @banned_word
    else
      render json: { errors: @banned_word.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    @banned_word.destroy!
    head :no_content
  end

  private

  def set_banned_word
    @banned_word = BannedWord.find(params.expect(:id))
  end

  def banned_word_params
    params.expect(banned_word: [ :phrase, :active ])
  end
end
