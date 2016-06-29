*-----------------------------------------------------------
* Title      : 68k Homebrew ROM Monitor and BIOS
* Written by : Hayden Kroepfl (ChartreuseK)
* Date       : June 28th 2016
* Description: A simple ROM monitor and BIOS for my homebrew 68k SBC
*-----------------------------------------------------------
*
* Bugs:
*   Graphical banner not displayed. Lines not in graphics mode
*   After reset, first input command doesn't work.
*   (Tabs partly broken due to odd rendering in Easy68K)
*
*

*****************************************************************
**** Config Defines *********************************************
*****************************************************************
RAM_START       	equ $800000     * Base Address of RAM
RAM_END         	equ $804000     * End Address of RAM
MAX_LINE_LENGTH 	equ 80			* Line buffer length

TERM_WIDTH      	equ 80			* Display width
TERM_HEIGHT     	equ 25			* Display height

DUMP_BYTES_LINE     equ 16        	* Number of bytes to display on a line
DUMP_BYTES_QUICK    equ 16          * Number of bytes to quick display
DUMP_BYTES_PAGE     equ 256         * Number of bytes to page display



*****************************************************************
**** Memory Locations *******************************************
*****************************************************************
BIOS_DATA_AREA	equ	RAM_END-$100

	OFFSET	BIOS_DATA_AREA		* Following labels are at the location specified
ram_size:	DS.L	1			* Calculated RAM size
trapv0:		DS.L	1			* Settable trap vectors
trapv1:		DS.L	1
trapv2:		DS.L	1
trapv3:		DS.L	1
trapv4:		DS.L	1
trapv5:		DS.L	1
trapv6:		DS.L	1
trapv7:		DS.L	1
trapv8:		DS.L	1
trapv9:		DS.L	1
trapv10:	DS.L	1
trapv11:	DS.L	1
trapv12:	DS.L	1
trapv13:	DS.L	1
trapv14:	DS.L	1
autov1:		DS.L	1			* Autovector interrupt 1 vector
div0v:      DS.L    1
chkv:		DS.L	1
trapvv:		DS.L	1
privv:		DS.L	1
tracev:		DS.L	1
vect_tmp:	DS.L	1			* Temporary location for use in vectors for saving SP or such

	ORG 	*					* Return to normal flow
	
	* Currently 168 bytes left for the exception stack
BIOS_STACK		equ BIOS_DATA_AREA + $100		
		

* Monitor Variables
varSTART		equ	BIOS_DATA_AREA				   	* Top of monitor variables
varCurAddr     	equ varStart-4                      * Last address accessed
varLineBuf     	equ varCurAddr-MAX_LINE_LENGTH-4    * Line buffer

varLAST			equ varLineBuf	

STACK_START		equ varLast

	
		
*********************************
* 68681 DUART Register Addresses
*
DUART           equ $100000     * Base Addr of DUART
MRA             equ DUART+0     * Mode Register A           (R/W)
SRA             equ DUART+2     * Status Register A         (r)
CSRA            equ DUART+2     * Clock Select Register A   (w)
CRA             equ DUART+4     * Commands Register A       (w)
RBA             equ DUART+6     * Receiver Buffer A         (r)
TBA             equ DUART+6     * Transmitter Buffer A      (w)
ACR             equ DUART+8     * Aux. Control Register     (R/W)
ISR             equ DUART+10    * Interrupt Status Register (R)
IMR             equ DUART+10    * Interrupt Mask Register   (W)
CUR             equ DUART+12    * Counter MSB               (R)
CTUR            equ DUART+12    * Counter/Timer Upper Reg   (W)
CLR             equ DUART+14    * Counter LSB               (R)
CTLR            equ DUART+14    * Counter/Timer Lower Reg   (W)
MRB             equ DUART+16    * Mode Register B           (R/W)
SRB             equ DUART+18    * Status Register B         (R)
CSRB            equ DUART+18    * Clock Select Register B   (W)
CRB             equ DUART+20    * Commands Register B       (W)
RBB             equ DUART+22    * Reciever Buffer B         (R)
TBB             equ DUART+22    * Transmitter Buffer B      (W)
IVR             equ DUART+24    * Interrupt Vector Register (R/W)
IPUL            equ DUART+26    * Unlatched Input Port values (R)
OPCR            equ DUART+26    * Output Port Configuration Register (W)
STRT_CNTR       equ DUART+28    * Start-Counter Command (R)
OPR_SET         equ DUART+28    * Output Port Bit Set Command (W)
STOP_CNTR       equ DUART+30    * Stop-Counter Command (R) / Clear timer interrupt
OPR_CLR         equ DUART+28    * Output Port Bit Clear Command (W)

**********************************
* YM2149 Sound chip registers
*
YM2149          equ $200000     * YM2149 Base Address
YM2149_SREG     equ YM2149+0    * Register Select   (W)
YM2149_WVAL     equ YM2149+2    * Write Value       (W)
YM2149_RVAL     equ YM2149+0    * Read Value        (R)

*****************************************************************
**** Other Defines **********************************************
*****************************************************************

**********************************
* ASCII Control Characters
*
BEL   equ $07
BKSP  equ $08       * CTRL-H
TAB   equ $09
LF    equ $0A
CR    equ $0D
ESC   equ $1B

CTRLC	EQU	$03     
CTRLX	EQU	$18     * Line Clear





    ORG     $000000
*****************************************************************
**** Exception Vector Table *************************************
*****************************************************************
* FIRST 8 bytes loaded after reset
*
    DC.l    STACK_START  * 0 - Supervisor stack pointer (After Reset)
    DC.l    START        * 1 - Initial PC (Reset Vector)
    DC.l    RESETVECT    * 2 - Bus Error
    DC.l    RESETVECT    * 3 - Address Error
    DC.l    RESETVECT    * 4 - ILLEGAL Instruction
    DC.l    DIV0VECT     * 5 - Divide by Zero
    DC.l    CHKVECT	     * 6 - CHK
    DC.l    TRAPVVECT    * 7 - TRAPV
    DC.l    PRIVVECT     * 8 - Privilage Violation
    DC.l    TRACEVECT    * 9 - Trace
    DC.l    UNHANDLED    * 10- Line 1010/Unused/Unimplemented Instruction
    DC.l    UNHANDLED    * 11- Line 1111/Unused/Unimplemented Instruction
    DC.l    UNHANDLED    * 12- Unused/Reserved
    DC.l    UNHANDLED    * 13- Unused/Reserved
    DC.l    UNHANDLED    * 14- Unused/Reserved
    DC.l    UNHANDLED    * 15- Unused/Reserved
    DC.l    UNHANDLED    * 16- Uninitialized Interrupt Vector
    DC.l    UNHANDLED    * 17- Unused/Reserved
    DC.l    UNHANDLED    * 18- Unused/Reserved
    DC.l    UNHANDLED    * 19- Unused/Reserved
    DC.l    UNHANDLED    * 20- Unused/Reserved
    DC.l    UNHANDLED    * 21- Unused/Reserved
    DC.l    UNHANDLED    * 22- Unused/Reserved
    DC.l    UNHANDLED    * 23- Unused/Reserved
    DC.l    UNHANDLED    * 24- Spurious Interrupt
    DC.l    AUTOVECT1    * 25- Autovector 1
    DC.l    UNHANDLED    * 26- Autovector 2
    DC.l    UNHANDLED    * 27- Autovector 3
    DC.l    UNHANDLED    * 28- Autovector 4
    DC.l    UNHANDLED    * 29- Autovector 5
    DC.l    UNHANDLED    * 30- Autovector 6
    DC.l    UNHANDLED    * 31- Autovector 7
    DC.l    TRAP0        * 32- TRAP #0
    DC.l    TRAP1        * 33- TRAP #1
    DC.l    TRAP2        * 34- TRAP #2
    DC.l    TRAP3        * 35- TRAP #3
    DC.l    TRAP4        * 36- TRAP #4
    DC.l    TRAP5        * 37- TRAP #5
    DC.l    TRAP6        * 38- TRAP #6
    DC.l    TRAP7        * 39- TRAP #7
    DC.l    TRAP8        * 40- TRAP #8
    DC.l    TRAP9        * 41- TRAP #9
    DC.l    TRAP10       * 42- TRAP #10
    DC.l    TRAP11       * 43- TRAP #11
    DC.l    TRAP12       * 44- TRAP #12
    DC.l    TRAP13       * 45- TRAP #13
    DC.l    TRAP14       * 46- TRAP #14
    DC.l    TRAP15       * 47- TRAP #15
    
    * 48-63 Unassigned/Reserved
    DCB.L   16,UNHANDLED  * Unassigned/Reserved
    * 64-255 User, 
    DCB.L   192,UNHANDLED  * User Vectors - Unused since we're using autovector interrupts
    
    
    
    
    
*****************************************************************
**** Monitor Entry Point ****************************************
*****************************************************************
START:                  
	bsr.w	display_init
	bsr.w	beep			
	
	
	* This will overwrite the stack so don't call as a function
clear_ram:
	lea     RAM_START, A2
 .loop:
    move.b  #$00, (A2)   	* Clear the memory
    cmp.b   #$00, (A2)+  	* Make sure it got cleared
    bne.s   .fail 
    cmp.l   #RAM_END, A2  
    blt.s   .loop        	* While we're still below the end of ram to clear
    bra.s	mon_start		* On success we can start
    
 .fail:
	move.l	#str_ram_fail, d0
	bsr.w	write_string
	move.l  A2, D0
    bsr.w   printHexAddr 	* Print out the address that failed
    
halt_loop:
	jmp		halt_loop
    

*****************************************************************
** Warm Start of monitor ****************************************
*****************************************************************
mon_start:
	* Clear Monitor Variables
	move.l	#0, varCurAddr
	move.l	#0, varLineBuf 
	
	bsr.w	clear_screen		* Clear the screen
	
	moveq	#0, d0				* Home the cursor
	bsr.w	set_cursor_pos
	
	move.b  #$80, d0			* Graphics mode, 80 col
	bsr.w   line_video_mode
	
	move.l	#str_graphic_banner, d0
	move.w	#(80*3), d1	        * 3 lines ( 12 pixels tall )
	bsr.w	write_string_len    * Write our 160x12 graphic banner to the display
	
	move.l  #00030000, d0       * Move to the start of the 4th row
	bsr.w   set_cursor_pos
	
	move.b	#$03, d0			* 80 column, bold text
	bsr.w	line_video_mode
	
	move.l	#str_banner, d0		* Write our text banner to the display
	bsr.w	write_string

	move.l	#str_quickhelp, d0	* Display quick help
	bsr.w	write_string

mon_line:
	move.l	varCurAddr, d0		* Read in current address
	bsr.w	printHexAddr
	
	move.l	#str_prompt, d0		* Display the prompt
	bsr.w	write_string

	bsr.w	readLine			* Read in the line
	bsr.w	lineToUpper		    * Convert to all upper case
	bsr.w	parseLine			* Parse the line
	
	bra.s	mon_line			







******
* Read in a line into the line buffer
readLine:
    movem.l d2/a2, -(SP)     * Save changed registers
    lea     varLineBuf, a2   * Start of the lineBuffer
    eor.w   d2, d2           * Clear the character counter
 .loop:
    bsr.w   read_char        * Read a character from the serial port
    cmp.b   #BKSP, d0        * Is it a backspace?
    beq.s   .backspace
    cmp.b   #CTRLX, d0       * Is it Ctrl-H (Line Clear)?
    beq.s   .lineclear
    cmp.b   #CR, d0          * Is it a carriage return?
    beq.s   .endline
    cmp.b   #LF, d0          * Is it anything else but a LF?
    beq.s   .loop            * Ignore LFs and get the next character
 .char:                      * Normal character to be inserted into the buffer
    cmp.w   #MAX_LINE_LENGTH, d2
    bge.s   .loop            * If the buffer is full ignore the character
    move.b  d0, (a2)+        * Otherwise store the character
    addq.w  #1, d2           * Increment character count
    bsr.w   write_char          * Echo the character
    bra.s   .loop            * And get the next one
 .backspace:
    tst.w   d2               * Are we at the beginning of the line?
    beq.s   .loop            * Then ignore it
    bsr.w   write_char       * Backspace
    move.b  #' ', d0
    bsr.w   write_char       * Space
    move.b  #BKSP, d0
    bsr.w   write_char       * Backspace
    subq.l  #1, a2           * Move back in the buffer
    subq.l  #1, d2           * And current character count
    bra.s   .loop            * And goto the next character
 .lineclear:
    tst     d2               * Anything to clear?
    beq.s   .loop            * If not, fetch the next character
    suba.l  d2, a2           * Return to the start of the buffer
 .lineclearloop:
    move.b  #BKSP, d0
    bsr.w   write_char       * Backspace
    move.b  #' ', d0
    bsr.w   write_char       * Space
    move.b  #BKSP, d0
    bsr.w   write_char       * Backspace
    subq.w  #1, d2          
    bne.s   .lineclearloop   * Go till the start of the line
    bra.s   .loop   
 .endline:
    bsr.w   write_char       * Echo the CR
    move.b  #LF, d0
    bsr.w   write_char       * Line feed to be safe
    move.b  #0, (a2)         * Terminate the line (Buffer is longer than max to allow this at full length)
    movea.l a2, a0           * Ready the pointer to return (if needed)
    movem.l (SP)+, d2/a2     * Restore registers
    rts                      * And return



***************************************
* Converts input line to uppercase
lineToUpper:
    lea     varLineBuf, a0   * Get the start of the line buffer
 .loop:
    move.b  (a0), d0         * Read in a character
    cmp.b   #'a', d0         
    blt.s   .next            * Is it less than lower-case 'a', then move on
    cmp.b   #'z', d0
    bgt.s   .next            * Is it greater than lower-case 'z', then move on
    sub.b   #$20, d0         * Then convert a to A, b to B, etc.
 .next:
    move.b  d0, (a0)+        * Store the character back into a0, and move to the next
    bne.s   .loop            * Keep going till we hit a null terminator
    rts



***************************************
* Parse Line
parseLine:
    movem.l a2-a3, -(SP)        * Save registers
    lea     varLineBuf, a0
 .findCommand:
    move.b  (a0)+, d0
    cmp.b   #' ', d0            * Ignore spaces
    beq.w   .findCommand    
    cmp.b   #'E', d0            * Examine command
    beq.w   .examine
    cmp.b   #'D', d0            * Deposit command
    beq.w   .deposit
    cmp.b   #'R', d0            * Run command
    beq.w   .run
    cmp.b   #'H', d0            * Help command
    beq.w   .help
    cmp.b	#'T', d0			* Trap 15 command
    beq.w	.trap
    cmp.b   #0, d0              * Ignore blank lines
    beq.s   .exit               
 .invalid:       
    move.l  #str_invalid_cmd, d0
    bsr.w   write_string
 .exit:
    movem.l (SP)+, a2-a3        * Restore registers
    rts

**********************
* Examines memory addresses
* Valid modes:
*   e ADDR                  Displays a single byte
*   e ADDR-ADDR             Dispalys all bytes between the two addresses
*   e ADDR+LEN              Dispays LEN bytes after ADDR
*   e ADDR;                 Interactive mode, space shows a page, enter shows quick amount.
*   e ADDR.                 Quick line, displays one line 
 .examine:
    bsr.w   parseNumber         * Read in the start address
    tst.b   d1                  * Make sure it's valid (parseNumber returns non-zero in d1 for failure)
    bne.w   .invalidAddr        
    move.l  d0, a3              * Save the start address
 .exloop:
    move.b  (a0)+, d0
    cmp.b   #' ', d0            * Ignore spaces
    beq.s   .exloop
    cmp.b   #'-', d0            * Check if it's a range specifier
    beq.s   .exrange
    cmp.b   #'+', d0            * Check if it's a length specifier
    beq.s   .exlength
    cmp.b   #';', d0            * Check if we're going interactive
    beq.s   .exinter
    cmp.b   #'.', d0            * Check if quick 16 
    beq.s   .exquick
    move.l  #1, d0              * Otherwise read in a single byte
    bra.s   .exend              
 .exrange:
    bsr.w   parseNumber         * Find the end address
    tst.b   d1                  * Check if we found a valid address
    bne.w   .invalidAddr
    sub.l   a3, d0              * Get the length
    bra.s   .exend
 .exquick:                      * Quick mode means show quick amount bytes
    move.l  #DUMP_BYTES_QUICK, d0
    bra.s   .exend
 .exlength:                     * Length mode means a length is specified
    bsr.w   parseNumber         * Find the length
    tst.b   d1
    bne.w   .invalidAddr
 .exend:                        * We're done parsing, give the parameters to dumpRAM and exit
    move.l  a3, a0
    bsr.w   dumpRAM
    bra.s   .exit
 .exinter:                      * Interactive mode, Space dumps a page worth of lines, enter shows quick amount
    move.l  a3, a0              * Current Address
    move.l  #DUMP_BYTES_QUICK, d0 * Quick amount
    bsr.w   dumpRAM             * Dump this line
    add.l   #DUMP_BYTES_QUICK, a3 * Move up the current address by Quick amount bytes
 .exinterend:
    bsr.w   read_char
    cmp.b   #CR, d0             * Display another line
    beq.s   .exinter
    cmp.b   #' ', d0            * Display a page 
    beq.s   .exinterpage
    bra.s   .exit               * Otherwise exit
 .exinterpage:
    move.l  a3, a0

    move.l  #DUMP_BYTES_PAGE, d0  * 138 bytes can fit in the 32x24 screen, 256 is 16 lines on 80x25
    bsr.w   dumpRAM               * Dump 
    add.l   #DUMP_BYTES_PAGE, a3  * Move up the current address by 256
    bra.s   .exinterend

****************************************
* Deposit values into RAM
* d ADDR VAL VAL            Deposit value(s) into RAM
* d ADDR VAL VAL;           Deposit values, continue with values on next line
*  VAL VAL VAL;              - Continuing with further continue
* d: VAL VAL                Continue depositing values after the last address written to
 .deposit:
    move.b  (a0), d0
    cmp.b   #':', d0            * Check if we want to continue from last
    beq.s   .depCont
    
    bsr.w   parseNumber         * Otherwise read the address
    tst.b   d1
    bne.w   .invalidAddr
    move.l  d0, a3              * Save the start address
 .depLoop:
    move.b  (a0), d0            
    cmp.b   #';', d0            * Check for continue
    beq.s   .depMultiline
    tst     d0                  * Check for the end of line
    beq     .depEnd
    
    bsr.w   parseNumber         * Otherwise read a value
    tst.b   d1
    bne.w   .invalidVal
    cmp.w   #255, d0            * Make sure it's a byte
    bgt.w   .invalidVal
    
    move.b  d0, (a3)+           * Store the value into memory
    bra.s   .depLoop
    
 .depCont:
    move.l  varCurAddr, a3      * Read in the last address 
    addq.l  #1, a0              * Skip over the ':'
    bra.s   .depLoop
    
 .depMultiline:
    move.l  #str_deposit_prompt, d0
    bsr.w   write_string
    
    bsr.w   readLine            * Read in the next line to be parsed
    
    bsr.w   lineToUpper         * Convert to uppercase
    lea     varLineBuf, a0      * Reset our buffer pointer
    bra.s   .depLoop            * And jump back to decoding
 .depEnd:
    move.l  a3, varCurAddr
    bra.w   .exit
****************************************
* 
 .run:
    bsr.w   parseNumber         * Otherwise read the address
    tst.b   d1
    bne.s   .invalidAddr
    move.l  d0, a0
    jsr     (a0)                * Jump to the code! 
                                * Go as subroutine to allow code to return to us
    jmp     mon_start           * Warm start after returning so everything is in
                                * a known state.
    
 .help:
    move.l  #str_fullhelp, d0
    bsr.w   write_string
    bra.w   .exit
******************************************
* t num a1 a2 a3 | Call a BIOS routine with arguments 
 .trap:
	movem.l d4-d7, -(sp)
	moveq.l	#0, d5				* Default arguments to 0
	moveq.l	#0, d6
	moveq.l	#0, d7
	bsr.w   parseNumber         * Try and read the routine number
    tst.b   d1
    bne.s   .invalidVal
    move.l	d0, d4				* Save the number
    
    move.b  (a0), d0            * Check we have parameters
    beq.s	.trapend
    bsr.w   parseNumber         * Try and read the first argument
    tst.b   d1
    bne.s   .invalidVal
    move.l	d0, d5				* Save the argument
    
    move.b  (a0), d0            * Check we have parameters
    beq.s	.trapend
    bsr.w   parseNumber         * Try and read the first argument
    tst.b   d1
    bne.s   .invalidVal
    move.l	d0, d6				* Save the argument
    
    move.b  (a0), d0            * Check we have parameters
    beq.s	.trapend
    bsr.w   parseNumber         * Try and read the first argument
    tst.b   d1
    bne.s   .invalidVal
    move.l	d0, d7				* Save the argument
 .trapend:
    move.l	d4, d0
    move.l  d5, d1
    move.l  d6, d2
    move.l  d7, d3
    trap #15					* BIOS trap
    
    movem.l (sp)+, d4-d7		* Restore regs
    bra.w	.exit
    
    
 .invalidAddr:
    move.l  #str_invalid_addr, d0
    bsr.w   write_string
    bra.w   .exit
 .invalidVal:
    move.l  #str_invalid_val, d0
    bsr.w   write_string
    bra.w   .exit
    


**************************************
* Find and parse a hex number
*  Starting address in A0
*  Number returned in D0
*  Status in D1   (0 success, 1 fail)
*  TODO: Try and merge first digit code with remaining digit code
parseNumber:
    eor.l   d0, d0           * Zero out d0
    move.b  (a0)+, d0
    cmp.b   #' ', d0         * Ignore all leading spaces
    beq.s   parseNumber
    cmp.b   #'0', d0         * Look for hex digits 0-9
    blt.s   .invalid
    cmp.b   #'9', d0
    ble.s   .firstdigit1

    cmp.b   #'A', d0         * Look for hex digits A-F
    blt.s   .invalid    
    cmp.b   #'F', d0
    ble.s   .firstdigit2
 .invalid:
    move.l  #1, d1          * Invalid character, mark failure and return
    rts
 .firstdigit2:
    sub.b   #'7', d0        * Turn 'A' to 10
    bra.s   .loop
 .firstdigit1:
    sub.b   #'0', d0        * Turn '0' to 0
 .loop:
    move.b  (a0)+, d1       * Read in a digit
    cmp.b   #'0', d1        * Look for hex digits 0-9
    blt.s   .end            * Any other characters mean we're done reading
    cmp.b   #'9', d1
    ble.s   .digit1
    cmp.b   #'A', d1        * Look for hex digits A-F
    blt.s   .end
    cmp.b   #'F', d1
    ble.s   .digit2

.end:                       * We hit a non-hex digit character, we're done parsing
    subq.l  #1, a0          * Move the pointer back before the end character we read
    move.l  #0, d1
    rts
 .digit2:
    sub.b   #'7', d1        * Turn 'A' to 10
    bra.s   .digit3
 .digit1:
    sub.b   #'0', d1        * Turn '0' to 0
 .digit3:
    lsl.l   #4, d0          * Shift over to the next nybble
    add.b   d1, d0          * Place in our current nybble (could be or.b instead)
    bra.s   .loop
    
    
****************************************
* Dumps a section of RAM to the screen
* Displays both hex values and ASCII characters
* d0 - Number of bytes to dump
* a0 - Start Address
dumpRAM:
    movem.l d2-d4/a2, -(SP)  * Save registers
    move.l  a0, a2           * Save the start address
    move.l  d0, d2           * And the number of bytes
 .line:
    move.l  a2, d0          
    bsr.w   printHexAddr     * Starting address of this line
    
    move.l  #str_addr_sep, d0
    bsr.w   write_string
    
    move.l  #DUMP_BYTES_LINE, d3 * Bytes that can be printed on a line
    move.l  d3, d4           * Save number of bytes on this line
 .hexbyte:
    tst.l   d2               * Check if we're out of bytes
    beq.s   .endbytesShort
    tst.b   d3               * Check if we're done this line
    beq.s   .endbytes    
    cmp.b   #8, d0
    bne.s   .nospace
    move.b  #' ', d0
    bsr.w   write_char
 .nospace:
    move.b  (a2)+, d0        * Read a byte in from RAM
    bsr.w   printHexByte     * Display it
    move.b  #' ', d0
    bsr.w   write_char          * Space out bytes
    subq.l  #1, d3    
    subq.l  #1, d2        
    bra.s   .hexbyte
 .endbytesShort:
    sub.b   d3, d4           * Make d4 the actual number of bytes on this line
    move.b  #' ', d0
 .endbytesShortLoop:
    tst.b   d3               * Check if we ended the line
    beq.s   .endbytes
    move.b  #' ', d0
    bsr.w   write_char          * Three spaces to pad out
    move.b  #' ', d0
    bsr.w   write_char
    move.b  #' ', d0
    bsr.w   write_char
    
    subq.b  #1, d3
    bra.s   .endbytesShortLoop
 .endbytes:
    suba.l  d4, a2           * Return to the start address of this line
 .endbytesLoop:
    tst.b   d4               * Check if we're done printing ascii
    beq     .endline    
    subq.b  #1, d4
    move.b  (a2)+, d0        * Read the byte again
    cmp.b   #' ', d0         * Lowest printable character
    blt.s   .unprintable
    cmp.b   #'~', d0         * Highest printable character
    bgt.s   .unprintable
    bsr.w   write_char
    bra.s   .endbytesLoop
 .unprintable:
    move.b  #'.', d0
    bsr.w   write_char
    bra.s   .endbytesLoop
 .endline:
    move.l  #str_newline, d0
    bsr.w   write_string
    tst.l   d2
    ble.s   .end
    bra.w   .line
 .end:
    movem.l (SP)+, d2-d4/a2  * Restore registers
    rts




** KEEP All printHex functions together **
******
* Print a hex word
printHexWord:
    move.l  d2, -(SP)    * Save D2
    move.l  d0, d2       * Save the address in d2
    
    rol.l   #8, d2       * 4321 -> 3214
    rol.l   #8, d2       * 3214 -> 2143 
    bra.s   printHex_wordentry  * Print out the last 16 bits
*****
* Print a hex 24-bit address
printHexAddr:
    move.l d2, -(SP)     * Save D2
    move.l d0, d2          * Save the address in d2
    
    rol.l   #8, d2       * 4321 -> 3214
    bra.s   printHex_addrentry  * Print out the last 24 bits
******
* Print a hex long
printHexLong:
    move.l  d2, -(SP)     * Save D2
    move.l  d0, d2        * Save the address in d2
    
    rol.l   #8, d2        * 4321 -> 3214 high byte in low
    move.l  d2, d0
    bsr.s   printHexByte  * Print the high byte (24-31)
printHex_addrentry:     
    rol.l   #8, d2        * 3214 -> 2143 middle-high byte in low
    move.l  d2, d0              
    bsr.s   printHexByte  * Print the high-middle byte (16-23)
printHex_wordentry:    
    rol.l   #8, d2        * 2143 -> 1432 Middle byte in low
    move.l  d2, d0
    bsr.s   printHexByte  * Print the middle byte (8-15)
    rol.l   #8, d2
    move.l  d2, d0
    bsr.s   printHexByte  * Print the low byte (0-7)
    
    move.l (SP)+, d2      * Restore D2
    RTS
    
******
* Print a hex byte
*  - Takes byte in D0
printHexByte:
    move.l  D2, -(SP)
    move.b  D0, D2
    lsr.b   #$4, D0
    add.b   #'0', D0
    cmp.b   #'9', D0     * Check if the hex number was from 0-9
    ble.s   .second
    add.b   #7, D0       * Shift 0xA-0xF from ':' to 'A'
.second:
    bsr.w   write_char      * Print the digit
    andi.b  #$0F, D2     * Now we want the lower digit Mask only the lower digit
    add.b   #'0', D2
    cmp.b   #'9', D2     * Same as before    
    ble.s   .end
    add.b   #7, D2
.end:
    move.b  D2, D0
    bsr.w   write_char      * Print the lower digit
    move.l  (SP)+, D2
    rts


























*****************************************************************
**** BIOS Routines **********************************************
*****************************************************************
BIOS_TABLE:
    bra.w   write_char			* Each of these instructions are 4 bytes
    bra.w	write_string
    bra.w   read_char
    bra.w   read_char_nbk
    bra.w	set_cursor_pos
    bra.w	scroll
    bra.w	display_init
    bra.w	clear_screen
    
    bra.w   serial_write
    bra.w	serial_write_string
    bra.w   serial_read
    bra.w   serial_read_nbk
    bra.w	serial_status		
    bra.w	serial_set_baud		
    bra.w	serial_init			
    
    bra.w   screen_video_mode	
    bra.w   line_video_mode		
    bra.w   put_pixel			
    
    bra.w	get_ram_size		
    bra.w	get_ram_base		
    
    bra.w	beep				
    bra.w	delay				
    
    bra.w	read_sector			* Unimplemented
    bra.w	write_sector		* Unimplemented
    bra.w	drive_info			* Unimplemented

    ****** End Of Jump Table *****
    
************************************************************************
** Bios Trap Handler
************************************************************************
TRAP15:
bios_trap:
	move.l 	sp, vect_tmp	* Save the supervisor stack pointer
	lea		BIOS_STACK, sp
	
	movem.l d1-d3/a0-a2, -(sp)
    
    add.w	d0, d0			* Multiply routine number by 4 to get offset
    add.w	d0, d0			* into jump table
							
	exg.l	d0, d1			* Move first argument into d0
    exg.l	d1, d2			* Move second argument into d1
    exg.l	d2, d3			* Move third argument into d2
    
    lea     BIOS_TABLE, a2
    adda    d3, a2
    jsr     (a2)   
*    jmp		BIOS_TABLE(PC,d3.w)
    
    movem.l (sp)+, d1-d3/a0-a2
    move.l  vect_tmp, sp	* Restore stack pointer
    rte
  
  
  
  
  
  
  
  
*** BIOS Routines **************************************************
** These functions are free to use d0 - d2 and a0 - a2 as scratch **
** Arguments are passed in registers starting at d0               **
** Return value is in d0                                          **
********************************************************************  
    
    
******************    
** write_char   ** Output a character to the display (serial port A)
**              ** D0 - Byte to be sent
write_char:
    btst    #2, SRA     	* Check if transmitter is ready on channel 1
    beq     write_char  	* If not the wait for it.
    move.b  d0, TBA     	* Transmit character
    rts
  
  
    
******************    
** write_string ** Output a null terminated string to the display (serial port A)
**        takes ** D0 - Address of string
write_string:   
	move.l	d0, a0
 .loop:
	move.b 	(a0)+, d0		* Read a byte, move to the next
	beq.s	.end			* Is it the null terminator?
	bsr.s	write_char		* Write the byte
	bra.s	.loop
 .end:
	rts
	
**********************    
** write_string_len ** Output a string of specified length to the display (serial port A)
**            takes ** D0 - Address of string
**					** D1.W - Length of string
write_string_len:   
	move.l	d0, a0
 .loop:
	move.b 	(a0)+, d0		* Read a byte, move to the next
	bsr.s	write_char		* Write the byte
	dbra	d1, .loop		* Loop for the length
 .end:
	rts
		
   
    
******************    
** read_char    ** Read a character from the keyboard (serial port A)
**              **  blocking if none are available.
**      returns ** D0 - Byte recieved
read_char:
    btst    #0,  SRA    	* Check if receiver ready bit is set
    beq     read_char
    eor.l   d0, d0
    move.b  RBA, d0     	* Read Character into D0
    rts
  
  
    
*******************    
** read_char_nbk ** Read a character from the keyboard (serial port A)
**               **  or 0 if none are available
**       returns ** D0 - Byte recieved or 0 if none available.
read_char_nbk:
    eor.l   d0, d0
    btst    #0,  SRA    	* Check if receiver ready bit is set
    beq     .none
    move.b  RBA, d0     	* Read Character into D0
 .none:
    rts
    
    
    
********************    
** set_cursor_pos ** Sets the current cursor position
**                **  
**          takes ** D0 - Low word column,  High word row
set_cursor_pos:
	move.l	d0, d1			* Save the position
	
	moveq   #$0E, d0		* Set Column code
    bsr.s	write_char
    move.l	d2, d0			* Write the column (low byte)
    bsr.s	write_char
    
    move.b  #$0F, d0		* Set Row code
    bsr.s	write_char
    swap	d0				* Move row to low word
    bsr.s	write_char	
    rts    
    
    
    
******************
** scroll       ** Scroll the screen forward or backward
**        takes ** D0.B - Signed number of lines to scroll. Negative is backward
scroll:
	move.l	d0, d1			* Save number of lines
	moveq	#$15,d0			* Scroll down
	tst.b   d1
	bge.s	.looptst
	moveq   #$14,d0			* Scroll up
	neg.b	d1
 .loop:
	bsr.s	write_char	
 .looptst:
	dbra	d1, .loop
	rts
	
	
	
******************    
** display_init ** Re-initializes the display serial port (A) on the DUART
**				** Clears the display, and homes the cursor
**              **  38400 8N1	
display_init:
	move.b  #$30, CRA       * Reset Transmitter
    move.b  #$20, CRA       * Reset Reciever
    move.b  #$10, CRA       * Reset Mode Register Pointer
    
    move.b  #$70, ACR       * Baud Rate Set #1, Timer (Crystal/16)
    move.b  #$CC, CSRA      * Set Tx and Rx rates to 38400 
    move.b  #$93, MRA       * 8-bit, No Parity ($93 for 8-bit, $92 for 7-bit), RxRDY irq type
    move.b  #$17, MRA       * Normal Mode, No RTS, CTS on IP0, 1 stop bit
				   
	move.b  #$05, CRA       * Enable Transmit/Recieve
	
	moveq	#$18, d0		# Set font attribute for line
	bsr.w	write_char
	moveq	#$03, d0		# 80 column, bold, normal height
	bsr.w	write_char
	
	moveq   #$0C, d0		* Clear Screen
	bsr.w	write_char
	moveq   #$01, d0		* Home cursor
	bsr.w	write_char
	moveq  	#$03, d0		* Blinking cursor
	bsr.w	write_char
	
	moveq   #$02, d0		* Set cursor char
	bsr.w	write_char
	move.b	#$DB, d0		* Solid block character 
	bsr.w	write_char
	
	rts
	
	
	
******************    
** clear_screen ** Clear the display
clear_screen:
	moveq	#$0C, d0		* Clear screen
	bsr.w	write_char
	rts
	
	

******************    
** serial_write ** Output a byte to serial port B
**        takes ** D0 - Byte to be sent
serial_write:
    btst    #2, SRB     	* Check if transmitter is ready on channel 1
    beq     serial_write	* If not the wait for it.
    move.b  d0, TBB     	* Transmit character
    rts
    
    
    
*************************    
** serial_write_string ** Output a null terminated string to serial port B
**                     ** D0 - Address of string
serial_write_string:   
	movea.l	d0, a0
 .loop:
	move.b 	(a0)+, d0
	beq.s	.end
	bsr.s	serial_write
	bra.s	.loop
 .end:
	rts
	
    
    
*****************************
** serial_write_string_len ** Output a string of specified length to serial port B
**            		 takes ** D0 - Address of string
**						   ** D1 - Length of string
serial_write_string_len:   
	move.l	d0, a0
 .loop:
	move.b 	(a0)+, d0		* Read a byte, move to the next
	bsr.s	serial_write	* Write the byte
	dbra	d1, .loop		* Loop for the length
 .end:
	rts
    

    
******************    
** serial_read  ** Read a character from the keyboard (serial port A)
**              **  blocking if none are available.
**      returns ** D0 - Byte recieved
serial_read:
    btst    #0,  SRB    	* Check if receiver ready bit is set
    beq     serial_read
    eor.l   d0, d0
    move.b  RBB, d0     	* Read Character into D0
    rts
    
    
    
*********************
** serial_read_nbk ** Read a character from the keyboard (serial port A)
**                 **  or 0 if none are available
**         returns ** D0.B - Byte recieved or 0 if none available.
serial_read_nbk:
    eor.l   d0, d0
    btst    #0,  SRB    	* Check if receiver ready bit is set
    beq     .none
    move.b  RBB, d0     	* Read Character into D0
 .none:
    rts



*******************    
** serial_status ** Returns the status byte of the serial port
**       returns ** D0.B - SRB status byte
serial_status:
    move.b	SRB, d0
    rts



*********************    
** serial_set_baud ** Returns the status byte of the serial port (B)
**           takes ** D0.B - Baud rate from the 68681 datasheet
				   **      - Upper nybble is receiver clock, lower is transmitter
				   **
				   ** We can only use Set 1 since the display (port A)
				   **  is set to 38400 baud.
				   **  
				   ** Set 1
				   **  0 - 50, 1 - 110, 2 - 134.5, 3 - 200, 4 - 300, 5 - 600
				   **  6 - 1200, 7 - 1050, 8 - 2400, 9 - 4800, A - 7200
				   **  B - 9600, C - 38400, D - timer, E - IP5-16x, F - IP5-1x
				   ** Set 2
				   **  0 - 75, 1 - 110, 2 - 134.5, 3 - 150, 4 - 300, 5 - 600
				   **  6 - 1200, 7 - 2000, 8 - 2400, 9 - 4800, A - 1800
				   **  B - 9600, C - 19200, D - timer, E - IP5-16x, F - IP5-1x
				   ** On receiver clock E and F are IP2 instead of IP5
serial_set_baud:
	move.b  d0, CSRB		* Change the baud rate
	rts
	
	
	
*****************    
** serial_init ** Re-initializes the serial port (B) on the DUART
**             **  9600 8N1
serial_init:
	move.b  #$30, CRB       * Reset Transmitter
    move.b  #$20, CRB       * Reset Reciever
    move.b  #$10, CRB       * Reset Mode Register Pointer
    
    move.b  #$70, ACR       * Baud Rate Set #1, Timer (Crystal/16)
    move.b  #$BB, CSRB      * Set Tx and Rx rates to 9600 (38400 $CC)
    move.b  #$93, MRB       * 8-bit, No Parity ($93 for 8-bit, $92 for 7-bit), RxRDY irq type
    move.b  #$07, MRB       * Normal Mode, No RTS, No CTS, 1 stop bit
				   
	move.b  #$05, CRB       * Enable Transmit/Recieve
	rts



***********************    
** screen_video_mode ** Sets the display mode for the entire screen, clearing it in the process
**                   ** D0.B - Display mode - 
**					 **     - 0x80 - graphics mdoe
**					 **		- 0x04 - Double height
**					 **		- 0x02 - Bold
**					 **		- 0x01 - 80 col (vs 40 col)
screen_video_mode:
	bsr.s	line_video_mode
	moveq	#$0C, d0		* Clear screen
	bsr.w	write_char
	rts


	
***********************    
** line_video_mode   ** Sets the display mode for the current line
**                   ** D0.B - Display mode - 
**					 **     - 0x80 - graphics mdoe
**					 **		- 0x04 - Double height
**					 **		- 0x02 - Bold
**					 **		- 0x01 - 80 col (vs 40 col)
line_video_mode:
	move.b	d0, d1
	
	moveq	#$18, d0		* Set line video mode
	bsr.w	write_char
	move.b  d1, d0			* To the specified mode
	bsr.w	write_char
	rts


	
***************
** put_pixel ** Set a pixel at the specified coords to the specified value
**     takes ** D0  - low word - x - high word - y
**           ** D1  - pixel value
put_pixel:
	move.l	d0, d2
	tst		d1
	bne.s	.set
 .clear:	
	moveq   #$06, d0		* Reset pixel
	bsr.w	write_char
	move.l	d2, d0			* X 
	bsr.w	write_char
	swap	d0				* Y
	bsr.w	write_char
	rts
	
 .set:
	moveq   #$05, d0		* Reset pixel
	bsr.w	write_char
	move.l	d2, d0			* X 
	bsr.w	write_char
	swap	d0				* Y
	bsr.w	write_char
	rts



******************
** get_ram_size ** Return the amount of available RAM in the system
**              **  minus the space reserved by the BIOS.
**		returns ** D0 - Amount of available RAM
get_ram_size:
	move.l	ram_size, d0
	rts



******************
** get_ram_base ** Return the starting address of free RAM
**		returns ** D0 - Starting address of free RAM
get_ram_base:
	move.l	#RAM_START, d0
	rts
	
	
	
******************
** beep         **  Plays a short fixed tone beep, a terminal bell.
beep:
	move.b 	#$00, YM2149_SREG    * Select reg 0 chan a fine
    move.b 	#$00, YM2149_WVAL    * 
    move.b 	#$01, YM2149_SREG    * chan a rough tune
    move.b 	#$01, YM2149_WVAL
    
    move.b 	#$07, YM2149_SREG    * Mixer reg
    move.b 	#$FE, YM2149_WVAL
    
    move.b 	#$08, YM2149_SREG    * Level chan a reg
    move.b 	#$0F, YM2149_WVAL
 
    move.b 	#$0d, YM2149_SREG    * Envelope shape
    move.b 	#$00, YM2149_WVAL    * None
    
    move.w	#200, d0			 * Wait 200ms
    bsr.s	delay
    
    move.b 	#$07, YM2149_SREG    * Mixer reg
    move.b 	#$FF, YM2149_WVAL	 * Disable all chanels
    
    move.b 	#$08, YM2149_SREG    * Level chan a reg
    move.b 	#$00, YM2149_WVAL	 * Mute channel A

    rts
    
    
	
******************
** delay        **  Delays for the specified number of milliseconds
**        takes **  D0.W - number of milliseconds   
delay:
    move.l	d0, d1			* 4 - Number of milliseconds
 .outer:
	move.w	#399, d0		* 8 - ( 398 * 10 + 8 + 14 = 3992 ) ~= 1ms @ 4MHz 
 .inner:					* If you add the 14 for the outer loop it becomes (4006)
	dbra.w	d0, .inner		* 10 on branch, 14 on fall through
	subq.w	#1, d1			* 4 - 
	bne.s	.outer			* 10 on branch, 8 on fall through 
	rts
	
	
read_sector:
write_sector:
drive_info:
	rts
	
	
*****************************************************************
**** Leapfrog vectors *******************************************
*****************************************************************
LEAPVECT MACRO
	move.l	sp, vect_tmp	* Save the stack pointer
	lea	 	BIOS_STACK, sp	* Swap to our own stack
	
	movem.l a0-a6/d0-d7, -(sp) * Save all registers
	
	move.l	(\1), a0		* Load the vector address
	cmp.l	#0, a0				* Check if not null
	beq.s	\@END			* 
	
	jsr	   (a0)				* Jump to the handler
\@END:
	movem.l (sp)+, a0-a6/d0-d7
	move.l	vect_tmp, sp	* Restore the stack
	rte

	ENDM

TRAP0:
	LEAPVECT	trapv0
TRAP1:
	LEAPVECT	trapv1
TRAP2:
	LEAPVECT	trapv2
TRAP3:
	LEAPVECT	trapv3
TRAP4:
	LEAPVECT	trapv4
TRAP5:
	LEAPVECT	trapv5
TRAP6:
	LEAPVECT	trapv6
TRAP7:
	LEAPVECT	trapv7
TRAP8:
	LEAPVECT	trapv8
TRAP9:
	LEAPVECT	trapv9
TRAP10:
	LEAPVECT	trapv10
TRAP11:
	LEAPVECT	trapv11
TRAP12:
	LEAPVECT	trapv12
TRAP13:
	LEAPVECT	trapv13
TRAP14:
	LEAPVECT	trapv14

AUTOVECT1:
	LEAPVECT	autov1
	
DIV0VECT:
    LEAPVECT    div0v
CHKVECT:
	LEAPVECT	chkv
TRAPVVECT:
	LEAPVECT	trapvv
PRIVVECT:
	LEAPVECT	privv
TRACEVECT:
	LEAPVECT	tracev
	


*****************************************************************
**** Hardcoded vectors ******************************************
*****************************************************************

**************
* Unhandled exceptions
UNHANDLED:
	rte	
	
**************
* Reset Vector
RESETVECT:
	reset
		


*****************************************************************
**** Strings ****************************************************
*****************************************************************

str_graphic_banner:
	dc.b $00,$00,$00,$00,$00,$00,$00,$00,$fa,$e4,$40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
     dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b $80,$10,$e0,$84,$78,$04,$e0,$fe,$ff,$55,$00,$00,$a0,$0c,$10,$54,$a8,$a0,$0c,$50,$58,$a4,$08,$5c,$a0,$0c,$50,$58,$0c,$a8,$00,$54,$58,$0c,$a0,$0c,$04,$00,$a0,$cc
     dc.b $04,$98,$64,$a8,$60,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b $02,$2d,$9b,$f6,$e4,$be,$ff,$c7,$40,$2b,$d0,$00,$0a,$30,$04,$17,$2b,$2a,$03,$15,$17,$25,$00,$15,$2a,$0b,$10,$27,$31,$0a,$30,$05,$32,$19,$0a,$33,$10,$00,$0a,$30
     dc.b $05,$25,$1a,$2a,$02,$14,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

str_banner:
	dc.b  	'68000 Monitor and BIOS by Hayden Kroepfl (c) 2016',CR,LF
	dcb.b 	72,$CD
    dc.b    CR, LF, CR, LF
	dc.b  	0
	
str_fullhelp:
	dc.b  	'e addr        | Dumps one byte at addr',CR,LF
	dc.b  	'e addr1-addr2 | Dumps all bytes from addr1 to addr2',CR,LF
	dc.b  	'e addr+len    | Dumps len bytes starting at addr',CR,LF
	dc.b  	'e addr.       | Dumps one line starting at addr',CR,LF
	dc.b  	'e addr;       | Interactive mode. Enter dumps one line, space dumps one page',CR,LF
	dc.b  	CR,LF
	dc.b  	'd addr v1 v2  | Deposits value(s) starting at addr',CR,LF
	dc.b  	'd addr v1 v2; | Same as above, but continue values on next line',CR,LF
	dc.b  	' v3 v4 v5;    |  Additional values, continue again on next line',CR,LF
	dc.b  	'd: v1 v2      | Deposit value(s) starting after last address accessed',CR,LF
	dc.b  	CR,LF
	dc.b  	'r addr        | Jump to the specified address and begin execution',CR,LF
	dc.b  	'r addr a a a  | As above but place passed arguments into d0, d1, d2 before hand',CR,LF  
	dc.b  	CR,LF
	dc.b    't rt a a a    | Call a BIOS routine rt with arguments',CR,LF
	dc.b    CR,LF
	dc.b  	'h             | Display this help screen',CR,LF
	dc.b  	CR,LF
	dc.b  	0

str_quickhelp:
	dc.b  	'e - examine, d - deposit, r - run, h - full help', CR,LF
	dc.b  	0

str_prompt:
	dc.b   	'> '
	dc.b   	0
	
str_addr_sep:
str_deposit_prompt:
	dc.b	': ',0
	
str_newline:
	dc.b	CR,LF,0
	

	
	
str_invalid_cmd:
	dc.b   	'Invalid command',CR,LF
	dc.b   	0
str_invalid_addr:
	dc.b   	'Invalid address',CR,LF
	dc.b	0
str_invalid_val:
	dc.b	'Invalid value',CR,LF
	dc.b	0
str_ram_fail:
	dc.b	'RAM check failed at 0x'
	dc.b 	0


*****************************************************************
**** End of Source **********************************************
*****************************************************************
    END    START        
    

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
