/******************************************************************************
* UART Communication Example
* This is written in a bare-metal, hardware-independent style so it can be adapted to STM32, NXP S32K, TI TMS570, Renesas RH850, Infineon AURIX, etc.
* Features:
* 1. UART Driver
* 2. UART RX Interrupt
* 3. Circular Buffer
* 4. Frame Parser FSM
* 5. CRC-8
* 6. Timeout Recovery
* 7. Main
******************************************************************************/

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>

/**********************************************************
 UART Registers (Dummy Hardware)
**********************************************************/

#define UART_TX_REG      (*(volatile uint8_t *)0x40001000)
#define UART_RX_REG      (*(volatile uint8_t *)0x40001004)
#define UART_STATUS      (*(volatile uint8_t *)0x40001008)

#define TX_READY         (1U<<0)
#define RX_READY         (1U<<1)

/**********************************************************
 Configuration
**********************************************************/

#define UART_BUFFER_SIZE     64
#define FRAME_HEADER         0xAA
#define MAX_PAYLOAD          32

#define CRC_POLY             0x07
#define CRC_INIT             0x00

/**********************************************************
 Circular Buffer
**********************************************************/

volatile uint8_t rxBuffer[UART_BUFFER_SIZE];

volatile uint8_t head = 0;
volatile uint8_t tail = 0;

/**********************************************************
 Frame Storage
**********************************************************/

uint8_t payload[MAX_PAYLOAD];

uint8_t payloadLength;

uint8_t receivedCRC;

/**********************************************************
 Timeout Counter
**********************************************************/

volatile uint32_t timeoutCounter = 0;

/**********************************************************
 CRC-8
**********************************************************/

uint8_t CRC8_Calculate(uint8_t *data, uint16_t length)
{
    uint8_t crc = CRC_INIT;

    for(uint16_t i=0;i<length;i++)
    {
        crc ^= data[i];

        for(uint8_t bit=0;bit<8;bit++)
        {
            if(crc & 0x80)
            {
                crc = (crc<<1)^CRC_POLY;
            }
            else
            {
                crc <<=1;
            }
        }
    }

    return crc;
}

/**********************************************************
 UART Send Byte
**********************************************************/

void UART_SendByte(uint8_t data)
{
    while(!(UART_STATUS & TX_READY));

    UART_TX_REG = data;
}

/**********************************************************
 UART Send Buffer
**********************************************************/

void UART_SendBuffer(uint8_t *data,uint16_t length)
{
    for(uint16_t i=0;i<length;i++)
    {
        UART_SendByte(data[i]);
    }
}

/**********************************************************
 UART RX Interrupt
**********************************************************/

void UART_RX_IRQHandler(void)
{
    uint8_t next;

    if(UART_STATUS & RX_READY)
    {
        next = (head+1)						%UART_BUFFER_SIZE;

        if(next != tail)
        {
            rxBuffer[head]=UART_RX_REG;

            head = next;
        }

        timeoutCounter = 0;
    }
}

/**********************************************************
 Read From Circular Buffer
**********************************************************/

bool UART_GetByte(uint8_t *data)
{
    if(head==tail)
        return false;

    *data = rxBuffer[tail];

    tail = (tail+1)                         %UART_BUFFER_SIZE;

    return true;
}

/**********************************************************
 Parser FSM
**********************************************************/

typedef enum
{
    WAIT_HEADER,

    WAIT_LENGTH,

    WAIT_PAYLOAD,

    WAIT_CRC

}ParserState;

ParserState parserState = WAIT_HEADER;

/**********************************************************
 Command Processing
**********************************************************/

void ProcessCommand(uint8_t *payload,uint8_t length)
{
    printf("Received Command : ");

    for(uint8_t i=0;i<length;i++)
    {
        printf("%c",payload[i]);
    }

    printf("\n");

    if(strcmp((char*)payload,"LED ON")==0)
    {
        printf("LED ON\n");
    }

    else if(strcmp((char*)payload,"LED OFF")==0)
    {
        printf("LED OFF\n");
    }

    else
    {
        printf("Unknown Command!!\n");
    }
}

/**********************************************************
 Frame Parser
**********************************************************/

void UART_FrameParser(void)
{
    uint8_t byte;

    static uint8_t index=0;

    static uint8_t frame[MAX_PAYLOAD+1];

    while(UART_GetByte(&byte))
    {
        switch(parserState)
        {

            case WAIT_HEADER:

                if(byte==FRAME_HEADER)
                {
                    parserState=WAIT_LENGTH;
                }

                break;

            case WAIT_LENGTH:

                payloadLength=byte;

                if(payloadLength>MAX_PAYLOAD)
                {
                    parserState=WAIT_HEADER;
                }
                else
                {
                    index=0;

                    parserState=WAIT_PAYLOAD;
                }

                break;

            case WAIT_PAYLOAD:

                payload[index]=byte;

                frame[index+1]=byte;

                index++;

                if(index>=payloadLength)
                {
                    parserState=WAIT_CRC;
                }

                break;

            case WAIT_CRC:

            {
                receivedCRC=byte;

                frame[0]=payloadLength;

                uint8_t crc;

                crc=CRC8_Calculate(frame,payloadLength+1);

                if(crc==receivedCRC)
                {
                    payload[payloadLength]='\0';

                    ProcessCommand(payload,payloadLength);
                }

                else
                {
                    printf("CRC Error\n");
                }

                parserState=WAIT_HEADER;

                break;
            }

            default:

                parserState=WAIT_HEADER;

                break;
        }
    }
}

/**********************************************************
 Timeout Handler
**********************************************************/

void UART_TimeoutTask(void)
{
    timeoutCounter++;

    if(timeoutCounter>500)
    {
        parserState = WAIT_HEADER;

        timeoutCounter=0;
    }
}

/**********************************************************
 Main
**********************************************************/

int main(void)
{
    while(1)
    {
        UART_FrameParser();

        UART_TimeoutTask();

        /* Other Application Tasks */

    }

    return 0;
}