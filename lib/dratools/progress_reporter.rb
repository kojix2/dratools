# frozen_string_literal: true

module Dratools
  # 対話的な端末のときだけ stderr へ一行進捗を表示する軽量レポーター。
  # データは stdout に出るため、stdout をパイプしても進捗は混ざらない。
  # 非 TTY（リダイレクト・パイプ・CI）では制御文字を出さず完全に無音にする。
  class ProgressReporter
    CLEAR_LINE = "\r\e[K"

    # 通常の出力の直前に、表示中の進捗行を消す IO ラッパー。
    class ClearingIO
      def initialize(io, reporter)
        @io = io
        @reporter = reporter
      end

      def puts(*args)
        @reporter.finish
        @io.puts(*args)
      end

      def print(*args)
        @reporter.finish
        @io.print(*args)
      end

      def write(*args)
        @reporter.finish
        @io.write(*args)
      end

      def flush
        @io.flush
      end

      def tty?
        @io.respond_to?(:tty?) && @io.tty?
      end

      def method_missing(name, ...)
        return super unless @io.respond_to?(name)

        @io.public_send(name, ...)
      end

      def respond_to_missing?(name, include_private = false)
        @io.respond_to?(name, include_private) || super
      end
    end

    def initialize(io: $stderr, enabled: nil)
      @io = io
      @enabled = enabled.nil? ? interactive?(io) : enabled
      @count = 0
      @active = false
    end

    def clearing_io(io = @io)
      ClearingIO.new(io, self)
    end

    # 1 件の進捗を表示する。直前の行を消してから上書きする。
    def report(label)
      return unless @enabled

      @count += 1
      @io.print("#{CLEAR_LINE}#{label} (#{@count})")
      @io.flush
      @active = true
    end

    # 残っている進捗行を消す。コマンド終了時（成功・失敗どちらでも）に呼ぶ。
    def finish
      return unless @active

      @io.print(CLEAR_LINE)
      @io.flush
      @active = false
    end

    private

    def interactive?(io)
      io.respond_to?(:tty?) && io.tty?
    end
  end
end
