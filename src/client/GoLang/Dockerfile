FROM golang:alpine
RUN apk update && apk upgrade && \
        apk add bash git openssh

ADD ./configfactory /go/src/configfactory
ADD ./main.go /go/src/
ADD ./go.mod /go/src/
ADD ./go.sum /go/src/
WORKDIR /go/src
#ENV GOPATH=/go/srv
#RUN go get github.com/hashicorp/vault/api
#RUN go get github.com/hashicorp/vault/command/agent/auth
#RUN go get github.com/hashicorp/vault/command/agent/auth/kubernetes
#RUN go get github.com/hashicorp/vault/sdk/helper/logging
#RUN go get k8s.io/client-go@v0.17.3
#RUN go get k8s.io/apimachinery@v0.17.3
RUN go build -o main .

CMD go run main.go