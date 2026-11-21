! A missing registration in the erased copy of a generic message with a
! trait parameter (DI extension E10) reaches its `error stop`: resolving a
! trait for which the container has no factory through class(IResolver)
! stops with "No registration available for IUnused!", whose name the erased
! copy reads from the trait descriptor. Registered with FAIL.
! GFortran does not accept this LFortran extension.
module traits_trait_param_runtime_02_m
    implicit none
    private
    public :: IResolver, ILogger, IUnused, Container

    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), intent(in), pass :: self
            class(P), allocatable :: res
        end function resolve
    end interface IResolver

    abstract interface :: ILogger
        integer function log(self, n)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: n
        end function log
    end interface ILogger

    abstract interface :: IUnused
        subroutine unused(self)
            type(itself), intent(in), pass :: self
        end subroutine unused
    end interface IUnused

    type, implements(ILogger) :: Logger
        integer :: lvl = 10
    contains
        procedure :: log => logger_log
    end type Logger

    type, sealed, implements(IResolver) :: Container
        integer :: lvl = 20
    contains
        procedure :: resolve
    end type Container

contains

    integer function logger_log(self, n)
        class(Logger), intent(in) :: self
        integer, intent(in) :: n
        logger_log = self%lvl + n
    end function logger_log

    function resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        class(*), allocatable :: made
        made = Logger(self%lvl)
        select type (obj => made)
        class is (P)
            res = obj
        class default
            error stop "No registration available for " // type_name{P}() // "!"
        end select
    end function resolve

end module traits_trait_param_runtime_02_m

program traits_trait_param_runtime_02
    use traits_trait_param_runtime_02_m
    implicit none
    type(Container) :: cont
    class(IResolver), allocatable :: r
    class(ILogger), allocatable :: l
    class(IUnused), allocatable :: u

    r = cont
    l = r%resolve{ILogger}()
    if (l%log(1) /= 21) error stop 1
    print '(a)', 'resolving IUnused'
    u = r%resolve{IUnused}()
    print '(a)', 'not reached'
end program traits_trait_param_runtime_02
