from fastapi import FastAPI, HTTPException, Query
import typing
from typing import Dict

app = FastAPI()

data = {
    "1": "Leader, CEO, Team Leader, businessman, govt jobs, Managers, born to lead others",
    "2": "Creative Person, Artist, chef, singer, relationship coach, public relations, tarot reading, acting",
    "3": "communication, fields like training, Teaching, Occult, Public Speaking, Consulting, Counselling",
    "4": "Techie, Engineering, Programming, Stock Market, Army",
    "5": "Born Traveller, Flight Attendants, Pilot, Public Speaking, Journalist, lawyer",
    "6": "Born Glam, Fashion Designer, Actor, Social media influencer, Doctor, interior designer, Restaurant owner, chef",
    "7": "Born Mysterious, Astrology, Occult science, Researchers, detectives, Ayurveda Doctor",
    "8": "Born Finance Person, Banking, Govt jobs, finance, science and politicians",
    "9": "Born to give and full of energy, Opening an NGO, Healers, Police, Business, construction, engineers, Real Estate."
}

def calculate_single_digit(num: int) -> int:
    while num >= 10:
        num = sum(int(digit) for digit in str(num))
    return num

def calculate_birthdate_sum(year: int, month: int, day: int) -> Dict[str, str]:
    birthdate = f"{year}{month}{day}"
    birthdate_digits = ''.join(filter(str.isdigit, birthdate))
    birthdate_sum = sum(map(int, birthdate_digits))
    single_digit_sum = calculate_single_digit(birthdate_sum)
    return {"output": data.get(str(single_digit_sum), "No matching output found for the given birthdate sum."),
            "Destiny Number": single_digit_sum}

@app.get("/")
def read_root():
    return {"Destiny": "World"}

@app.get("/destiny")
async def get_birthdate_output(year: int = Query(...), month: int = Query(...), day: int = Query(...)):
    try:
        result = calculate_birthdate_sum(year, month, day)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/destiny_number")
async def get_birthdate_output(year: int = Query(...), month: int = Query(...), day: int = Query(...)):
    try:
        result = calculate_birthdate_sum(year, month, day)
        return result["Destiny Number"]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

