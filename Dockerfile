FROM nginx:1.28.0-alpine-slim
USER root
COPY conf/nginx/ /etc/nginx/
COPY conf/resolv.conf /etc/resolv.conf
EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]
