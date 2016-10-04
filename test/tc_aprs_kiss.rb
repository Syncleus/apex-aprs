require 'test/unit'
require 'kiss/test/kiss_mock'
require_relative '../lib/apex/aprs_kiss'

module Apex
    DECODED_FRAME_KISS = {
        :source => 'W2GMD-1',
        :destination => 'OMG',
        :path => ['WIDE1-1', 'WIDE2-2'],
        :text => 'test_encode_frame'
    }
    ENCODED_FRAME_KISS = [192, 0, 158, 154, 142, 64, 64, 64, 96, 174, 100, 142, 154, 136, 64, 98, 174, 146, 136, 138, 98,
                          64, 98, 174, 146, 136, 138, 100, 64, 101, 3, 240, 116, 101, 115, 116, 95, 101, 110, 99, 111, 100,
                          101, 95, 102, 114, 97, 109, 101, 192]

    DECODED_FRAME_KISS_INVALID = {
        :source => 'KG6WTF',
        :destination => 'S7TSUV',
        :path => ['MTOSO-2', 'WIDE2*' 'qAR', 'KF6FIR-10'],
        :text => '`17El#X-/kg6wtf@gosselinfamily.com'
    }
    ENCODED_FRAME_KISS_INVALID = [192, 0, 166, 110, 168, 166, 170, 172, 96, 150, 142, 108, 174, 168, 140, 96, 154, 168, 158,
                                  166, 158, 64, 100, 174, 146, 136, 138, 100, 226, 130, 164, 224, 150, 140, 108, 140, 146, 164,
                                  117, 3, 240, 96, 49, 55, 69, 108, 35, 88, 45, 47, 107, 103, 54, 119, 116, 102, 64, 103, 111,
                                  115, 115, 101, 108, 105, 110, 102, 97, 109, 105, 108, 121, 46, 99, 111, 109, 192]

    class TestKiss < Test::Unit::TestCase
        def test_read
            kiss_mock = Kiss::KissMock.new
            aprs_kiss = AprsKiss.new(kiss_mock)

            kiss_mock.clear_interface
            kiss_mock.add_read_from_interface(ENCODED_FRAME_KISS)
            translated_frame = nil
            iter_left = 1000
            while iter_left > 0 and not translated_frame
                translated_frame = aprs_kiss.read
                iter_left -= 1
            end

            assert_equal DECODED_FRAME_KISS, translated_frame
        end

        def test_write
            kiss_mock = Kiss::KissMock.new
            aprs_kiss = AprsKiss.new(kiss_mock)

            kiss_mock.clear_interface
            aprs_kiss.write(DECODED_FRAME_KISS)

            all_raw_frames = kiss_mock.get_sent_to_interface

            assert_equal ENCODED_FRAME_KISS, all_raw_frames[0]
        end

        def test_read_invalid
            kiss_mock = Kiss::KissMock.new
            aprs_kiss = AprsKiss.new(kiss_mock)

            kiss_mock.clear_interface
            kiss_mock.add_read_from_interface(ENCODED_FRAME_KISS_INVALID)
            translated_frame = nil
            iter_left = 1000
            while iter_left > 0 and not translated_frame
                translated_frame = aprs_kiss.read
                iter_left -= 1
            end

            assert_equal nil, translated_frame
        end

        def test_write_invalid
            kiss_mock = Kiss::KissMock.new
            aprs_kiss = AprsKiss.new(kiss_mock)

            kiss_mock.clear_interface
            aprs_kiss.write(DECODED_FRAME_KISS_INVALID)

            all_raw_frames = kiss_mock.get_sent_to_interface

            assert_equal 0, all_raw_frames.length
        end
    end
end