import logging


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    # httpx (used by python-telegram-bot's HTTP layer) logs every poll request at INFO —
    # too noisy for long-polling; keep it at WARNING.
    logging.getLogger("httpx").setLevel(logging.WARNING)
