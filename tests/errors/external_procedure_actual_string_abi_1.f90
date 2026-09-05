! A separately compiled external procedure receives a CHARACTER dummy by the
! classic Fortran external ABI (a hidden trailing length), a dummy procedure
! by LFortran's descriptor ABI. Binding one to the other would call the
! procedure with the wrong argument list, so it is refused.
module external_procedure_actual_string_abi_1
    implicit none
    interface
        subroutine record_len_1(msg, n)
            character(len=*), intent(in) :: msg
            integer, intent(out) :: n
        end subroutine
        subroutine driver_1(cb, n)
            interface
                subroutine cb(msg, n)
                    character(len=*), intent(in) :: msg
                    integer, intent(out) :: n
                end subroutine
            end interface
            integer, intent(out) :: n
        end subroutine
    end interface
contains
    subroutine run_1(n)
        integer, intent(out) :: n
        call driver_1(record_len_1, n)
    end subroutine
end module
