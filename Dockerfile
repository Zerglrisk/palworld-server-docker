FROM steamcmd/steamcmd:debian-12

USER root
RUN apt-get update && apt-get install -y libgcc-s1 gosu && rm -rf /var/lib/apt/lists/*

# steam 유저 생성
RUN groupadd -g 1000 steam && useradd -m -u 1000 -g 1000 steam

COPY start.sh /start.sh
RUN chmod +x /start.sh

# 포트는 환경변수 PORT, QUERY_PORT, REST_API_PORT, RCON_PORT로 설정 가능
EXPOSE 8211/udp   
EXPOSE 27015/udp  
EXPOSE 8212/tcp  
EXPOSE 25575/tcp 

ENTRYPOINT ["/start.sh"]