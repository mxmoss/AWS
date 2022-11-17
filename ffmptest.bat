rem This script starts ffmpeg with a test pattern and tone
C:\FFmpeg\bin\ffmpeg -f lavfi -re -i testsrc=duration=300:size=1280x720:rate=30 -f lavfi -re -i sine=frequency=1000:duration=60:sample_rate=44100 -pix_fmt yuv420p -c:v libx264 -b:v 1000k -g 30 -keyint_min 120 -profile:v baseline -preset veryfast -f mpegts "udp://127.0.0.1:8080?pkt_size=1316"
