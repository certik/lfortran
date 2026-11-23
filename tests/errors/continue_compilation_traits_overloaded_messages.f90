! Overloaded generic messages in a trait (DI extension E6): overloads that
! are not distinguishable; an overloaded message that is not generic; a type
! whose generic binding has no specific for one overload, or a specific that
! does not match it; a call through a trait object that no overload accepts; a
! call through a generic parameter that no overload accepts; a non-generic
! message after a generic one; overloads mixing a function and a
! subroutine; two specifics that implement one overload; an implements-block
! binding of an overloaded message; generic messages of one name of two
! adopted traits that neither correspond nor are distinguishable; and the
! overloads of two adopted traits, one of which the type does not implement.
module continue_compilation_traits_overloaded_messages_m0
    implicit none
    private
    public :: ctor0, ctor1, ctor2, IContainer, IClient, Client, make_client, &
        make_pair

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0
        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
        function ctor2{Trait :: T1, Trait :: T2, U}(a, b) result(res)
            class(T1), intent(in) :: a
            class(T2), intent(in) :: b
            type(U) :: res
        end function ctor2
    end interface

    abstract interface :: IContainer
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{T1,U}) :: ctor
        end subroutine register
    end interface

    abstract interface :: IClient
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IClient

    type, implements(IClient) :: Client
        integer :: id = 0
    contains
        procedure :: serve => client_serve
    end type Client

contains

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%id
    end function client_serve

    function make_client() result(res)
        type(Client) :: res
    end function make_client

    function make_pair(a, b) result(res)
        class(IClient), intent(in) :: a, b
        type(Client) :: res
        res%id = a%serve() + b%serve()
    end function make_pair

end module continue_compilation_traits_overloaded_messages_m0

! Not distinguishable: both dummy procedures have interfaces of no arguments.
module continue_compilation_traits_overloaded_messages_m1
    use continue_compilation_traits_overloaded_messages_m0, only: ctor0
    implicit none

    abstract interface :: ISame
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
        subroutine register{Trait :: Q, Q :: V}(self, make)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{V}) :: make
        end subroutine register
    end interface
end module continue_compilation_traits_overloaded_messages_m1

! Only generic messages can be overloaded.
module continue_compilation_traits_overloaded_messages_m2
    implicit none

    abstract interface :: IRun
        subroutine run(self)
            type(itself), pass, intent(inout) :: self
        end subroutine run
        subroutine run(self, n)
            type(itself), pass, intent(inout) :: self
            integer, intent(in) :: n
        end subroutine run
    end interface
end module continue_compilation_traits_overloaded_messages_m2

! The generic binding has no specific for the second overload.
module continue_compilation_traits_overloaded_messages_m3
    use continue_compilation_traits_overloaded_messages_m0, only: ctor0, IContainer
    implicit none

    type, sealed, implements(IContainer) :: Container
        integer :: n = 0
    contains
        generic :: register => register0
        procedure :: register0
    end type Container

contains

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = self%n + 1
    end subroutine register0
end module continue_compilation_traits_overloaded_messages_m3

! The specific for the second overload has a receiver of another intent.
module continue_compilation_traits_overloaded_messages_m4
    use continue_compilation_traits_overloaded_messages_m0, only: ctor0, ctor1, IContainer
    implicit none

    type, sealed, implements(IContainer) :: Container
        integer :: n = 0
    contains
        generic :: register => register0, register1
        procedure :: register0, register1
    end type Container

contains

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = self%n + 1
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        type(Container), intent(in) :: self
        procedure(ctor1{T1,U}) :: ctor
    end subroutine register1
end module continue_compilation_traits_overloaded_messages_m4

! A call of an overloaded message through a trait object that no overload
! accepts.
module continue_compilation_traits_overloaded_messages_m5
    use continue_compilation_traits_overloaded_messages_m0, only: IContainer, &
        IClient, make_pair
    implicit none

contains

    subroutine use_object(c)
        class(IContainer), intent(inout) :: c
        call c%register{IClient}(make_pair)
    end subroutine use_object
end module continue_compilation_traits_overloaded_messages_m5

! No overload accepts a constructor of two arguments.
module continue_compilation_traits_overloaded_messages_m6
    use continue_compilation_traits_overloaded_messages_m0, only: IContainer, &
        IClient, make_pair
    implicit none

contains

    subroutine setup{IContainer :: CT}(cont)
        type(CT), intent(inout) :: cont
        call cont%register{IClient}(make_pair)
    end subroutine setup
end module continue_compilation_traits_overloaded_messages_m6

! Only generic messages can be overloaded, also after a generic one.
module continue_compilation_traits_overloaded_messages_m7
    implicit none

    abstract interface :: IRun
        subroutine run{Trait :: P}(self)
            type(itself), pass, intent(inout) :: self
        end subroutine run
        subroutine run(self, n)
            type(itself), pass, intent(inout) :: self
            integer, intent(in) :: n
        end subroutine run
    end interface
end module continue_compilation_traits_overloaded_messages_m7

! Overloads are all functions or all subroutines.
module continue_compilation_traits_overloaded_messages_m8
    implicit none

    abstract interface :: IMix
        subroutine run{Trait :: P}(self)
            type(itself), pass, intent(inout) :: self
        end subroutine run
        integer function run{Trait :: P}(self, n)
            type(itself), pass, intent(inout) :: self
            integer, intent(in) :: n
        end function run
    end interface
end module continue_compilation_traits_overloaded_messages_m8

! Two specifics of the generic binding implement the first overload.
module continue_compilation_traits_overloaded_messages_m9
    use continue_compilation_traits_overloaded_messages_m0, only: ctor0, ctor1, IContainer
    implicit none

    type, sealed, implements(IContainer) :: Container
        integer :: n = 0
    contains
        generic :: register => register0, register1, register0b
        procedure :: register0, register1, register0b
    end type Container

contains

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = self%n + 1
    end subroutine register0

    subroutine register0b{Trait :: Q, Q :: V}(self, make)
        type(Container), intent(inout) :: self
        procedure(ctor0{V}) :: make
    end subroutine register0b

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
    end subroutine register1
end module continue_compilation_traits_overloaded_messages_m9

! An overloaded message is implemented by the type's generic binding, not by
! a binding of an implements block.
module continue_compilation_traits_overloaded_messages_m10
    use continue_compilation_traits_overloaded_messages_m0, only: ctor0, ctor1, IContainer
    implicit none

    type :: Box
        integer :: n = 0
    contains
        generic :: register => register0, register1
        procedure :: register0, register1
    end type Box

    implements IContainer :: Box
        procedure, pass(self) :: register => register0
    end implements

contains

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        class(Box), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = self%n + 1
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        class(Box), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
    end subroutine register1
end module continue_compilation_traits_overloaded_messages_m10

! Generic messages of one name of two traits whose receivers differ: they
! neither correspond nor are distinguishable.
module continue_compilation_traits_overloaded_messages_m11
    use continue_compilation_traits_overloaded_messages_m0, only: ctor0
    implicit none

    abstract interface :: IIn
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(in) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
    end interface

    abstract interface :: IInOut
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
    end interface

    type, sealed, implements(IIn + IInOut) :: Box
        integer :: n = 0
    contains
        procedure :: register => register0
    end type Box

contains

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Box), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
    end subroutine register0
end module continue_compilation_traits_overloaded_messages_m11

! The overloads of two adopted traits combine; the type's generic binding
! has no specific for the one that only the second trait declares.
module continue_compilation_traits_overloaded_messages_m12
    use continue_compilation_traits_overloaded_messages_m0, only: ctor0, ctor1, &
        ctor2, IContainer
    implicit none

    abstract interface :: IPair
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor2{T1,T2,U}) :: ctor
        end subroutine register
    end interface

    type, sealed, implements(IContainer + IPair) :: Container
        integer :: n = 0
    contains
        generic :: register => register0, register1
        procedure :: register0, register1
    end type Container

contains

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = self%n + 1
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
    end subroutine register1
end module continue_compilation_traits_overloaded_messages_m12

! An implements-block binding not distinguishable from a specific of the
! type's generic binding of its name, with which it is one generic.
module continue_compilation_traits_overloaded_messages_m13
    implicit none

    abstract interface :: IServe
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IServe

    type :: Server
        integer :: id = 3
    contains
        generic :: serve => serve0
        procedure :: serve0
    end type Server

    implements IServe :: Server
        procedure :: serve => other
    end implements

contains

    integer function serve0(self)
        class(Server), intent(in) :: self
        serve0 = self%id
    end function serve0

    integer function other(self)
        class(Server), intent(in) :: self
        other = 42
    end function other

    integer function use_server(c)
        type(Server), intent(in) :: c
        use_server = c%serve()
    end function use_server
end module continue_compilation_traits_overloaded_messages_m13

! No specific of the generic binding implements the non-generic message.
module continue_compilation_traits_overloaded_messages_m14
    implicit none

    abstract interface :: IServe
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IServe

    type, implements(IServe) :: Server
        integer :: id = 3
    contains
        generic :: serve => serve_n, serve_x
        procedure :: serve_n, serve_x
    end type Server

contains

    integer function serve_n(self, n)
        class(Server), intent(in) :: self
        integer, intent(in) :: n
        serve_n = self%id * n
    end function serve_n

    integer function serve_x(self, x)
        class(Server), intent(in) :: self
        real, intent(in) :: x
        serve_x = self%id
    end function serve_x
end module continue_compilation_traits_overloaded_messages_m14

! The overloads have the same type parameters, so their dummy arguments
! tell them apart.
module continue_compilation_traits_overloaded_messages_m15
    implicit none

    abstract interface :: IServe
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IServe

    abstract interface :: IGet
        integer function get{Trait :: P}(self)
            type(itself), pass, intent(in) :: self
        end function get
        integer function get{Trait :: P}(self, n)
            type(itself), pass, intent(in) :: self
            integer, intent(in) :: n
        end function get
    end interface

contains

    integer function use_get{IGet :: G}(x) result(r)
        type(G), intent(in) :: x
        r = x%get{IServe}(1.5)
    end function use_get
end module continue_compilation_traits_overloaded_messages_m15

! Not distinguishable through an optional dummy argument.
module continue_compilation_traits_overloaded_messages_m16
    implicit none

    abstract interface :: IServe
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IServe

    type :: Server
        integer :: id = 3
    contains
        generic :: serve => serve_n
        procedure :: serve_n
    end type Server

    implements IServe :: Server
        procedure :: serve => other
    end implements

contains

    integer function serve_n(self, n)
        class(Server), intent(in) :: self
        integer, intent(in), optional :: n
        serve_n = self%id
    end function serve_n

    integer function other(self)
        class(Server), intent(in) :: self
        other = 42
    end function other
end module continue_compilation_traits_overloaded_messages_m16

! A generic implements-block binding and a generic specific of the type's
! generic binding that are not distinguishable.
module continue_compilation_traits_overloaded_messages_m17
    implicit none

    abstract interface :: IShow
        integer function tag(self)
            type(itself), intent(in), pass :: self
        end function tag
    end interface IShow

    abstract interface :: IServe
        integer function serve{IShow :: T}(self, x)
            type(itself), intent(in), pass :: self
            type(T), intent(in) :: x
        end function serve
    end interface IServe

    type :: Server
        integer :: id = 3
    contains
        generic :: serve => serve_t
        procedure :: serve_t
    end type Server

    implements IServe :: Server
        procedure :: serve => other
    end implements

contains

    integer function serve_t{IShow :: T}(self, x)
        class(Server), intent(in) :: self
        type(T), intent(in) :: x
        serve_t = self%id
    end function serve_t

    integer function other{IShow :: T}(self, x)
        class(Server), intent(in) :: self
        type(T), intent(in) :: x
        other = 42
    end function other
end module continue_compilation_traits_overloaded_messages_m17

! A reference that neither the implements-block binding nor a specific of
! the generic binding accepts lists both.
module continue_compilation_traits_overloaded_messages_m18
    implicit none

    abstract interface :: IServe
        integer function serve(self, x)
            type(itself), intent(in), pass :: self
            real, intent(in) :: x
        end function serve
    end interface IServe

    type :: Server
        integer :: id = 3
    contains
        generic :: serve => serve_n
        procedure :: serve_n
    end type Server

    implements IServe :: Server
        procedure :: serve => other
    end implements

contains

    integer function serve_n(self, n)
        class(Server), intent(in) :: self
        integer, intent(in) :: n
        serve_n = self%id * n
    end function serve_n

    integer function other(self, x)
        class(Server), intent(in) :: self
        real, intent(in) :: x
        other = 42
    end function other

    integer function use_server(c)
        type(Server), intent(in) :: c
        use_server = c%serve(.true.)
    end function use_server
end module continue_compilation_traits_overloaded_messages_m18

! A scalar actual argument of an implements-block binding whose dummy
! argument is an array.
module continue_compilation_traits_overloaded_messages_m19
    implicit none

    abstract interface :: IServe
        integer function serve(self, x)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: x(:)
        end function serve
    end interface IServe

    type :: Server
        integer :: id = 3
    end type Server

    implements IServe :: Server
        procedure :: serve => other
    end implements

contains

    integer function other(self, x)
        class(Server), intent(in) :: self
        integer, intent(in) :: x(:)
        other = size(x)
    end function other

    integer function use_server(c)
        type(Server), intent(in) :: c
        use_server = c%serve(2)
    end function use_server
end module continue_compilation_traits_overloaded_messages_m19
