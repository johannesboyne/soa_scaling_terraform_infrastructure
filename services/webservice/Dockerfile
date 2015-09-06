FROM alpine
EXPOSE 1337

RUN mkdir /data
RUN touch /data/test.txt

ADD main /
CMD ["/main"]
