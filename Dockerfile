FROM python:3

RUN pip3 install slackclient
RUN pip3 install requests

WORKDIR /usr/local/bin

COPY knotebot.py .
COPY sofie_status.py .
COPY team_members.py .

ENV SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN

CMD ["python3", "./knotebot.py"]
