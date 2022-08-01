FROM mcr.microsoft.com/mssql/server:2019-latest
ARG SA_PASSWORD
ENV SA_PASSWORD="Password01!!"
EXPOSE 1433
WORKDIR /
COPY ./adventureworks-light.bak .
COPY ./install.sql .
COPY ./install.sh .
COPY ./startup.sh .
CMD /bin/bash ./startup.sh
