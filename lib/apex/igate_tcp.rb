module Apex
    class IGateTcp
        DEFAULT_APRSIS_URL = 'http://srvr.aprs-is.net:8080'
        DEFAULT_APRSIS_SERVER = 'rotate.aprs.net'
        DEFAULT_APRSIS_FILTER_PORT = 14580

        protected
        def initialize(user, password='-1', input_url=None)
            @user = user
            if input_url
                @url = input_url
            else
                @url = DEFAULT_APRSIS_URL
            end
            @auth = ['user', user, 'pass', password, 'vers', 'APRS Python Module'].join(' ')
            @aprsis_sock = nil
            @data_buffer = ''
            @packet_buffer = []
            @lock = Mutex.new
        end

        private
        def reset_buffer
            @data_buffer = ''
            @packet_buffer = []
        end

        private
        def format_path(path_list)
            path_list.join(',')
        end

        private
        def encode_frame(frame)
            formatted_frame = [frame[:source], frame[:destination]].join('>')
            if frame[:path] and frame[:path].length > 0
                formatted_frame = [formatted_frame, format_path(frame[:path])].join(',')
            end
            formatted_frame += ':'
            formatted_frame += frame[:text]
            return formatted_frame
        end

        private
        def decode_frame(frame)
            decoded_frame = {}
            frame_so_far = ''
            path = nil
            frame.chars.each do |char|
                if char == '>' and !decoded_frame.include? :source
                    decoded_frame[:source] = frame_so_far
                    frame_so_far = ''
                elsif char == ':' and !path
                    path = frame_so_far
                    frame_so_far = ''
                else
                    frame_so_far = [frame_so_far, char].join
                end
            end

            path = path.split(',')
            decoded_frame[:destination] = path.shift
            decoded_frame[:path] = path
            decoded_frame[:text] = frame_so_far

            decoded_frame
        end

        public
        def connect(server=nil, port=nil, aprs_filter=nil, *args, **kwargs)
            @lock.synchronize do
                unless @aprsis_sock
                    reset_buffer

                    unless server
                        server = DEFAULT_APRSIS_SERVER
                    end

                    unless port
                        port = DEFAULT_APRSIS_FILTER_PORT
                    end

                    unless aprs_filter
                        aprs_filter = ['p', @user].join('/')
                    end

                    @full_auth = [@auth, 'filter', aprs_filter].join(' ')

                    @server = server
                    @port = port
                    @aprsis_sock = TCPSocket.open(@server, @port)
                    @aprsis_sock.puts( (@full_auth + '\r\n').map{ |c| c.ord } )
                end
            end
        end

        public
        def close(*args, **kwargs)
            @lock.synchronize do
                if @aprsis_sock
                    @aprsis_sock.close
                    reset_buffer
                    @aprsis_sock = nil
                end
            end
        end

        public
        def read(filter_logresp=true, *args, **kwargs)
            @lock.synchronize do
                # check if there is any data waiting
                read_more = true
                while read_more
                    selected = IO.select([@aprsis_sock], [], [], 0)
                    if selected.first.length > 0
                        recvd_data = @aprsis_sock.gets
                        if recvd_data
                            @data_buffer += recvd_data
                        end
                    else
                        read_more = false
                    end
                end

                # check for any complete packets and move them to the packet buffer
                if @data_buffer.include? '\r\n'
                    partial = true
                    if @data_buffer.end_with? '\r\n'
                        partial = false
                    end

                    packets = @data_buffer.split('\r\n')
                    if partial
                        @data_buffer = packets.pop.dup
                    else
                        @data_buffer = ''
                    end

                    packets.each do |packet|
                        @packet_buffer << packet.dup
                    end
                end

                # return the next packet that matches the filter
                while @packet_buffer.length > 0
                    packet = @packet_buffer.pop
                    unless filter_logresp and packet.start_with?('#') and packet.include? 'logresp'
                        return decode_frame(packet)
                    end
                end

                return nil
            end
        end

        public
        def write(frame, *args, **kwargs)
            @lock.synchronize do
                encoded_frame = encode_frame(frame)
                @aprsis_sock.puts( encoded_frame.map { |c| c.ord } )
            end
        end
    end
end