#!/usr/bin/env ruby
# frozen_string_literal: false

require 'optparse'
require 'net/https'
require 'json'
require 'uri'
require 'time'

version = 'v0.0.2'

# Optparser
banner = <<HEREDOC
  check_gitlab #{version} [https://gitlab.com/bsv9/check_veeam_em]
  This plugin checks Veeam task status via Veeam Backup Enterprise Manager
  Usage: #{File.basename(__FILE__)} [options]
HEREDOC

options = { port: 9398, warning: 2, critical: 5 }
OptionParser.new do |opts| # rubocop:disable  Metrics/BlockLength
  opts.banner = banner.to_s
  opts.separator ''
  opts.separator 'Options:'
  opts.on('-a', '--address ADDRESS', 'Veeam EM base API host ') do |s|
    options[:address] = s
  end
  opts.on('-p', '--port PORT', 'API port') do |t|
    options[:port] = t
  end
  opts.on('-k', '--insecure', 'No ssl verification') do |k|
    options[:insecure] = k
  end
  opts.on('-n', '--name NAME', 'Job name') do |n|
    options[:name] = n
  end
  opts.on('-U', '--username USERNAME', 'Username') do |k|
    options[:username] = k
  end
  opts.on('-P', '--password PASSWORD', 'Password') do |m|
    options[:password] = m
  end
  opts.on('-w', '--warning WARNING', 'Warning days threshold') do |w|
    options[:warning] = w.to_i
  end
  opts.on('-c', '--critical CRITICAL', 'Critical days threshold') do |c|
    options[:critical] = c.to_i
  end
  opts.on('-v', '--version', 'Print version information') do
    puts "check_veeam_em #{version}"
  end
  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit(0)
  end
  ARGV.push('-h') if ARGV.empty?
end.parse!

# check required args
%i[address name username password].each do |arg|
  raise OptionParser::MissingArgument if options[arg].nil?
end

# Check Veeam EM
class CheckVeeamEM
  def initialize(options)
    @options = options
    @sessions = { success: nil, warning: nil }

    # login call
    make_request('/api/sessionMngr/?v=latest', :post)
  end

  def run
    args = {
      type: 'BackupJobSession', filter: "JobName==#{@options[:name]}",
      format: 'entities', pageSize: 5, sortDesc: 'EndTime'
    }

    response = make_request("/api/query?#{URI.encode_www_form(args)}")
    response['Entities']['BackupJobSessions']['BackupJobSessions'].each do |job|
      backup_time = Time.parse(job['EndTimeUTC'])
      @sessions[:success] = backup_time if job['Result'] == 'Success' && @sessions[:success].nil?
      @sessions[:warning] = backup_time if job['Result'] == 'Warning' && @sessions[:warning].nil?
    end
    check_thresholds
  end

  def check_thresholds
    unless @sessions[:success].nil?
      if Time.now - @sessions[:success] > 86_400 * @options[:critical]
        crit_msg("Last run more than #{@options[:critical]} days ago - #{@sessions[:success]}")
      end
      if Time.now - @sessions[:success] > 86_400 * @options[:warning]
        warn_msg("Last run more than #{@options[:warning]} days ago - #{@sessions[:success]}")
      end
      ok_msg("Job completed successfully #{@sessions[:success]}")
    end

    warn_msg("Job completed with warnings - #{@sessions[:warning]}") unless @sessions[:warning].nil?
    crit_msg('Last success backup not found')
  end

  private

  # define some helper methods for naemon
  def ok_msg(message)
    puts "OK - #{message}"
    exit 0
  end

  def crit_msg(message)
    puts "Critical - #{message}"
    exit 2
  end

  def warn_msg(message)
    puts "Warning - #{message}"
    exit 1
  end

  def unk_msg(message)
    puts "Unknown - #{message}"
    exit 3
  end

  # create url
  def make_request(path, method = :get)
    uri = URI("https://#{@options[:address]}:#{@options[:port]}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @options[:insecure]

    request = (method == :get ? Net::HTTP::Get : Net::HTTP::Post).new(uri.request_uri)

    request.basic_auth(@options[:username], @options[:password])
    request['Accept'] = 'application/json'
    request['X-RestSvcSessionId'] = @token unless @token.nil?
    response = http.request(request)

    unk_msg('Not enough data received. Make API call manually to verify').to_s if response.content_length < 3
    unk_msg(response.message).to_s unless %w[200 201].include?(response.code)

    @token = response['X-RestSvcSessionId'] if response.key?('X-RestSvcSessionId')
    JSON.parse(response.body)
  rescue StandardError => e
    unk_msg(e)
  end
end

vem = CheckVeeamEM.new(options)
vem.run
